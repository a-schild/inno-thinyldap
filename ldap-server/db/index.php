<?php
// Definierten der include Dateien
require 'PHPExcel.php';
require_once 'PHPExcel/IOFactory.php';
require_once 'include/dbconn.inc.php';
?>
<html>
    <head>
        <title>inno-ldap phonebook</title>
        <link href="css/style.css" rel="stylesheet">
    </head>
    <body>
        <div class="uploadform">
            <form action="" method="post" enctype="multipart/form-data">
                <div class="uploadform_titel">    
                    Innovaphone simple phonebook
                </div> 
                <div class="uploadform_content">
                    <div class="uploadform_left">
                        <div style="text-align:right; vertical-align:central;">
                            Select xls or xlsx file
                        </div>
                    </div>
                    <div class="uploadform_right">
                        <div style="text-align:left; vertical-align:central;">
                            <input type="file" name="file" id="file" multiple style="height:auto"/><br/>
                            <input type="submit" name="btnInput" value="Import data"/>
                        </div>
                    </div>
                </div>
                <div class="uploadform_content">
                    <div class="uploadform_left">
                        <div style="text-align:right; vertical-align:central;">
							<input type="submit" name="btnInput" value="Show existing data"/>
                        </div>
                    </div>
                    <div class="uploadform_right">
                        <div style="text-align:left; vertical-align:central;">
                            <a href="export.php">Download data</a>
                        </div>
                        <div style="text-align:right; vertical-align:right;">
                            <a href="testdata.xlsx">Download sample file</a>
                        </div>
                    </div>
                </div>

                <div class="uploadform_errordisplay" >
                    <?php
                    $company = "";
                    $firstname = "";
                    $lastname = "";
                    $address = "";
                    $zip = "";
                    $city = "";
                    $country = "";
                    $phone = "";
                    $mobile = "";
                    $fax = "";
                    $home= "";
                    $email = "";
                    $speeddial_phone = '';
                    $speeddial_mobile = '';
                    $speeddial_home= '';
                    $worksheetError = true;
                    $showData = false;

                    // Format phone numbers
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

                    // Pruefen ob die Verbindung zur Datenbank steht
                    if ($conn->connect_error) {
                        die("Database connection failed: " . $conn->connect_error);
                    }
					$conn->set_charset('utf8');

                    // Pruefen ob der Button "btnInput" geklickt wurde
                    try {
                        if (isset($_POST['btnInput']) && $_POST['btnInput'] == 'Import data') {
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
                                        "(company, firstname, lastname,address,zip,city,country, phone, mobile, fax, home, email, speeddial_phone, speeddial_mobile, speeddial_home) " .
                                        "values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");
                                $stmt->bind_param("sssssssssssssss", $company, $firstname, $lastname, 
                                                    $address, $zip, $city, $country, $phone, $mobile, $fax, 
                                                    $home, $email, 
                                                    $speeddial_phone, $speeddial_mobile, $speeddial_home);
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
                                    if ($worksheetTitle == "Phonebook") {
                                        $worksheetError = false;
                                        $cell = $worksheet->getCellByColumnAndRow(5, 1);
                                        $label = $cell->getValue();
										$companyCol= 0;
										$firstnameCol= 1;
										$lastnameCol= 2;
										$addressCol= 3;
										$zipCol= 4;
										$cityCol= 5;
										$countryCol= 6;
										$phoneCol= 7;
										$phoneSpeedDialCol=8;
										$mobileCol= 9;
										$mobileSpeedDialCol=10;
										$homeCol = 11;
										$homeSpeedDialCol = 12;
										$faxCol = 13;
										$emailCol = 14;

                                        // Laden der Zeilen und Spalten des Dokumentes
                                        for ($row = 2; $row <= $highestRow; ++$row) {
                                            $val = array();
                                            for ($col = 0; $col < $highestColumnIndex; ++$col) {
                                                $cell = $worksheet->getCellByColumnAndRow($col, $row);
                                                $val[] = $cell->getValue();
                                            }
                                            // Map excel to variables
                                            $company = $val[$companyCol];
                                            $firstname = $val[$firstnameCol];
                                            $lastname = $val[$lastnameCol];
                                            $address = $val[$addressCol];
                                            $zip = $val[$zipCol];
                                            $city = $val[$cityCol];
                                            $country = $val[$countryCol];
                                            $phone = formatting($val[$phoneCol]);
                                            $mobile = formatting($val[$mobileCol]);
											$home = formatting($val[$homeCol]);
                                            $fax = formatting($val[$faxCol]);
                                            $email = $val[$emailCol];
											$speeddial_phone = $val[$phoneSpeedDialCol];
											$speeddial_mobile = $val[$mobileSpeedDialCol];
											$speeddial_home = $val[$homeSpeedDialCol];
											if (is_numeric($phone) || is_numeric($mobile) || is_numeric($home))
											{
												$stmt->execute();
											}
                                        }
                                        echo("<p>Import of data suceeded</p>");
                                    }
                                    if ($worksheetError == true) {
                                        die("<p class='error_message'>The import file must have a sheet named 'Phonebook'!</p>");
                                    }
                                }
                                $stmt->close();
                                $showData = true;
                            } else {
                                die("<p class='error_message'>Only xls and xlsx files can be imported</p>");
                            }
                        } else if (isset($_POST['btnInput']) && $_POST['btnInput'] == 'Show existing data') {
                            $showData = true;
                        } else if (isset($_POST['btnInput'])) {
                            echo "Don't know what to do?<br>Action '" . $_POST['btnInput'] . "' unhandled";
                        }
                    } catch (PHPExcel_Exception $e) {
                        die("<p class='error_message'>Error loading file: " . $e->getMessage() . "<p>");
                    }
                    ?>
                </div>
            </form>
        </div>
        <?php if ($showData) { ?>
            <table class="uploadedtable">
                <tr>
                    <td colspan="7" class="uploadedtable_titel">    
                        Existing data
                    </td>
                </tr>
                <tr>
                    <td class="uploadedtable_header">Company</td>
                    <td class="uploadedtable_header">First name</td>
                    <td class="uploadedtable_header">Last name</td>
                    <td class="uploadedtable_header">Address</td>
                    <td class="uploadedtable_header">Zip</td>
                    <td class="uploadedtable_header">City</td>
                    <td class="uploadedtable_header">Country</td>
                    <td class="uploadedtable_header">Phone</td>
                    <td class="uploadedtable_header">KW Phone</td>
                    <td class="uploadedtable_header">Mobile</td>
                    <td class="uploadedtable_header">KW Mobile</td>
                    <td class="uploadedtable_header">Home</td>
                    <td class="uploadedtable_header">KW Home</td>
                    <td class="uploadedtable_header">Fax</td>
                    <td class="uploadedtable_header">Email</td>
                </tr>
                <?php

                // Prüfen ob die Verbindung zur Datenbank steht
                if ($conn->connect_error) {
                    die("DB connection failed: " . $conn->connect_error);
                }
				$conn->set_charset('utf8');

                $isEven= false;

                $res = $conn->query("select * from address ");
                while ($row = $res->fetch_assoc()) {
                    echo "<tr class='uploadedtable_".($isEven ? 'even' : 'odd')."'>";
                    echo "<td>";
                    echo $row['company'];
                    echo "</td><td>";
                    echo $row['firstname'];
                    echo "</td><td>";
                    echo $row['lastname'];
                    echo "</td><td>";
                    echo $row['address'];
                    echo "</td><td>";
                    echo $row['zip'];
                    echo "</td><td>";
                    echo $row['city'];
                    echo "</td><td>";
                    echo $row['country'];
                    echo "</td><td>";
                    echo $row['phone'];
                    echo "</td><td>";
                    echo $row['speeddial_phone'];
                    echo "</td><td>";
                    echo $row['mobile'];
                    echo "</td><td>";
                    echo $row['speeddial_mobile'];
                    echo "</td><td>";
                    echo $row['home'];
                    echo "</td><td>";
                    echo $row['speeddial_home'];
                    echo "</td><td>";
                    echo $row['fax'];
                    echo "</td><td>";
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