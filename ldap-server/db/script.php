<?php
// Definierten der include Dateien
require 'PHPExcel.php';
require_once 'PHPExcel/IOFactory.php';

// Definieren der Variabel
$servername = "127.0.0.1";
$username = "inno-ldap-db";
$password = "<password>";
$db = "phonebook_innovaphone";
?>
<html>
    <head>
        <title>Excel Datei importieren</title>
        <link href="css/style.css" rel="stylesheet">
    </head>
    <body>

        <div class="uploadform">
            <form action="" method="post" enctype="multipart/form-data">
                <div class="uploadform_titel">    
                    Excel Datei import
                </div> 
                <div class="uploadform_content">
                    <div class="uploadform_left">
                        <div style="text-align:right;	vertical-align:central;	">
                            Excel Datei ausw&auml;hlen
                        </div>
                    </div>
                    <div class="uploadform_right">
                        <div style="text-align:left;	vertical-align:central;	">
                            <input type="file" name="file" id="file" multiple style="height:auto"/>
                            <input type="submit" name="btnInput" value="Daten importieren"/>
                        </div>
                    </div>
                </div>
                <div class="uploadform_content">
                    <div class="uploadform_left">
                        <div style="text-align:right;	vertical-align:central;	">
 <input type="submit" name="btnInput" value="Bestehende Daten anzeigen"/>
                        </div>
                    </div>
                    <div class="uploadform_left">
                        <div style="text-align:right;	vertical-align:central;	">
                            <a href="export.php">Daten als Excel herunterladen</a>
                        </div>
                    </div>
                    <div class="uploadform_right">
                        <div style="text-align:left;	vertical-align:central;	">
                            
                        </div>
                    </div>
                    <div class="uploadform_right">
                        <div style="text-align:left;	vertical-align:central;	">
                            <a href="testdata.xlsx">Beispieldatei herunterladen</a>
                        </div>
                    </div>
                </div>

                <div class="uploadform_errordisplay" >
                    <?php
                    $company = "";
                    $person = "";
                    $phone = "";
                    $mobile = "";
                    $email = "";
                    $speeddial_phone = '';
                    $speeddial_mobile = '';
                    $worksheetError = true;
                    $showData = false;

                    // Formatieren der Telefonnummern
                    function formatting($number) {
                        if ($number != "") {
                            if (substr($number, 0, 2) == "+ ") {
                                $number = substr_replace($number, "", 1, 1);
                            }
                            if (substr($number, 0, 2) == "41") {
                                $number = substr_replace($number, "+41", 0, 2);
                            }
                            if (substr($number, 0, 3) == "0 (") {
                                $number = substr_replace($number, "", 0, 3);
                                $number = substr_replace($number, "", 4, 1);
                            }
                            if (substr($number, 0, 5) == "(+41)") {
                                if (substr($number, 6, 1) == "0") {
                                    $number = substr_replace($number, "", 0, 6);
                                } else {
                                    $number = str_replace("(", "", $number);
                                    $number = str_replace(")", "", $number);
                                }
                            }
                            if (substr($number, 0, 2) == "00") {
                                $number = substr_replace($number, "+", 0, 2);
                            }
                            if (substr($number, 4, 3) == "(0)") {
                                $number = substr_replace($number, "", 4, 4);
                            }
                            // Enfernen von Leerzeichen und anderen nicht-numerischen sachen
                            $number = str_replace("\xc2\xa0", "", $number);
                            $number = str_replace("-", "", $number);
                            $number = str_replace(" ", "", $number);
                            $number = str_replace("/", "", $number);
                            $number = str_replace("(0)", "", $number);

                            if (substr($number, 0, 1) == "0") {
                                $number = substr_replace($number, "+41", 0, 1);
                            }
                        }
                        return $number;
                    }

                    // Aufbauen der Verbindung zur Datenbank
                    $conn = new mysqli($servername, $username, $password, $db);

                    // Pruefen ob die Verbindung zur Datenbank steht
                    if ($conn->connect_error) {
                        die("Verbindung fehlgeschlagen: " . $conn->connect_error);
                    }
                    // Pruefen ob der Button "btnInput" geklickt wurde
                    try {
                        if (isset($_POST['btnInput']) && $_POST['btnInput'] == 'Daten importieren') {
                            // Abfragen der Dateiendung
                            $filepath = @$_FILES["file"]["name"];
                            $fileext = pathinfo($filepath, PATHINFO_EXTENSION);
                            if ($fileext == "xlsx" || $fileext == "xls") {
                                // Abfragen des Filenamen des Hochgeladen Dokuments
                                $filename = @$_FILES["file"]["tmp_name"];

                                // Leeren der Tabelle Addresse
                                $conn->query("TRUNCATE address");
                                // Erstellen des SQL Querys mit einem Prepare Statement
                                $stmt = $conn->prepare("insert into address " .
                                        "(company, person, phone, mobil, email, speeddial_phone, speeddial_mobile) " .
                                        "values(?,?,?,?,?,?,?)");
                                $stmt->bind_param("sssssss", $company, $person, $phone, $mobile, $email, $speeddial_phone, $speeddial_mobile);
                                try {
                                    // Laden der ausgewälten Datei
                                    $objPHPExcel = PHPExcel_IOFactory::load($filename);
                                } catch (PHPExcel_Reader_Exception $e) {
                                    die("<p class='error_message'>Fehler beim laden der Datei: " . $e->getMessage() . "<p>");
                                }
                                // Laden der Worksheets
                                foreach ($objPHPExcel->getWorksheetIterator() as $worksheet) {
                                    $worksheetTitle = $worksheet->getTitle();
                                    $highestRow = $worksheet->getHighestRow(); // e.g. 10
                                    $highestColumn = $worksheet->getHighestColumn(); // e.g 'F'
                                    $highestColumnIndex = PHPExcel_Cell::columnIndexFromString($highestColumn);
                                    $nrColumns = ord($highestColumn) - 64;
                                    // Abfragen des korrekten Worksheets
                                    if ($worksheetTitle == "Entreprise") {
                                        $worksheetError = false;
                                        $cell = $worksheet->getCellByColumnAndRow(5, 1);
                                        $label = $cell->getValue();
                                        $hasSpeedDial = ($label == "KurzwahlTel");
                                        echo $hasSpeedDial ? "Mit Kurzwahl" : "Ohne Kurzwahl";
                                        $companyCol = 1;
                                        $personCol = 2;
                                        $phoneCol = 4;
                                        $phoneSpeedDialCol = $hasSpeedDial ? 5 : -1;
                                        $mobileCol = $hasSpeedDial ? 6 : 5;
                                        $mobileSpeedDialCol = $hasSpeedDial ? 7 : -1;
                                        $emailCol = $hasSpeedDial ? 9 : 7;

                                        // Laden der Zeilen und Spalten des Dokumentes
                                        for ($row = 2; $row <= $highestRow; ++$row) {
                                            $val = array();
                                            for ($col = 0; $col < $highestColumnIndex; ++$col) {
                                                $cell = $worksheet->getCellByColumnAndRow($col, $row);
                                                $val[] = $cell->getValue();
                                            }
                                            // Speichern der Daten in die dafür vorgesehenen Variabeln
                                            $company = $val[$companyCol];
                                            //$company = utf8_decode($company);
                                            $companies[] = $company;
                                            $person = $val[$personCol];
                                            //$person = utf8_decode($person);
                                            $persons[] = $person;
                                            $phone = $val[$phoneCol];
                                            $phone = formatting($phone);
                                            //$phone = utf8_decode($phone);
                                            $phones[] = $phone;
                                            $mobile = $val[$mobileCol];
                                            $mobile = formatting($mobile);
                                            //$mobile = utf8_decode($mobile);
                                            $mobiles[] = $mobile;

                                            $email = $val[$emailCol];
                                            //$email = utf8_decode($email);
                                            $emails[] = $email;

                                            if ($hasSpeedDial) {
                                                $speeddial_phone = $val[$phoneSpeedDialCol];
                                                $speeddial_mobile = $val[$mobileSpeedDialCol];
                                            }
                                            $speeddial_phones[] = $speeddial_phone;
                                            $speeddial_mobiles[] = $speeddial_mobile;
                                            //var_dump($speeddial_phone);
                                            //var_dump($speeddial_mobile);

                                            if (is_numeric($phone) || is_numeric($mobile)) {
                                                //echo("<p>Zeile $row einfügen</p>");	
                                                $stmt->execute();
                                            } else {
                                                //echo("<p>Zeile $row hat keine Telefonnummern</p>");	
                                            }
                                        }
                                        echo("<p>Das Hochladen der Daten war erfolgreich</p>");
                                    }
                                    if ($worksheetError == true) {
                                        die("<p class='error_message'>Die ausgew&uaml;lte Datei muss ein Worksheet mit dem namen 'Entreprise' haben!</p>");
                                    }
                                }
                                $conn->close();
                                $stmt->close();
                                $showData = true;
                            } else {
                                die("<p class='error_message'>Es k&ouml;nnen nur Excel Dateien(.xlsx oder .xls) hochgeladen werden</p>");
                            }
                        } else if (isset($_POST['btnInput']) && $_POST['btnInput'] == 'Bestehende Daten anzeigen') {
                            $showData = true;
                        } else if (isset($_POST['btnInput'])) {
                            echo "Was soll gemacht werden?<br>Aktion '" . $_POST['btnInput'] . "' unbekannt";
                        }
                    } catch (PHPExcel_Exception $e) {
                        die("<p class='error_message'>Fehler beim laden der Datei: " . $e->getMessage() . "<p>");
                    }
                    ?>
                </div>
            </form>
        </div>
        <?php if ($showData) { ?>
            <table class="uploadedtable">
                <tr>
                    <td colspan="7" class="uploadedtable_titel">    
                        Vorhandene Daten
                    </td>
                </tr>
                <tr>
                    <td class="uploadedtable_header">Company</td>
                    <td class="uploadedtable_header">Person</td>
                    <td class="uploadedtable_header">Phone</td>
                    <td class="uploadedtable_header">KW Phone</td>
                    <td class="uploadedtable_header">Mobile</td>
                    <td class="uploadedtable_header">KW Mobile</td>
                    <td class="uploadedtable_header">Email</td>
                </tr>
                <?php
                $conn = new mysqli($servername, $username, $password, $db);

                // Prüfen ob die Verbindung zur Datenbank steht
                if ($conn->connect_error) {
                    die("Verbindung fehlgeschlagen: " . $conn->connect_error);
                }
                $isEven= false;

                $res = $conn->query("select * from address ");
                while ($row = $res->fetch_assoc()) {
                    echo "<tr class='uploadedtable_".($isEven ? 'even' : 'odd')."'>";
                    echo "<td>";
                    echo $row['company'];
                    echo "</td>";
                    echo "<td>";
                    echo $row['person'];
                    echo "</td>";
                    echo "<td>";
                    echo $row['phone'];
                    echo "</td>";
                    echo "<td>";
                    echo $row['speeddial_phone'];
                    echo "</td>";
                    echo "<td>";
                    echo $row['mobil'];
                    echo "</td>";
                    echo "<td>";
                    echo $row['speeddial_mobile'];
                    echo "</td>";
                    echo "<td>";
                    echo $row['email'];
                    echo "</td>";
                    echo"</tr>";
                    $isEven= !$isEven;
                }
                ?>
            </table>
        <?php } ?>
    </body>
</html>