<?php
// Definierten der benötigten Dateien
require 'PHPExcel.php';
require_once 'PHPExcel/IOFactory.php';

// Definieren der Variabel
$servername = "127.0.0.1";
//$username = "<db-login-username>";
//$password = "<db-password>;
//$db = "phonebook_innovaphone";

$username = "intermobility";
$password = "KXJVkE7v";
$db = "phonebook_intermobility";

?>
<html>
	<head>
		<title>Import Excel File into MySQL</title>
    <link href="css/style.css" rel="stylesheet">
	</head>
	<body>
		
    <div class="uploadform">
    	<form action="" method="post" enctype="multipart/form-data">
        	<div class="uploadform_titel">    
          	Import Excel Datei
          </div> 
          <div class="uploadform_content">
          	<div class="uploadform_left">
          		<div style="text-align:right;	vertical-align:central;	">
         	 			Excel Datei auswählen
          		</div>
          	</div>
          	<div class="uploadform_right">
          		<div style="text-align:left;	vertical-align:central;	">
    						<input type="file" name="file" id="file" multiple style="height:auto"/>
          		</div>
        		</div>
          </div>
          <div class="uploadform_content">
            <div class="uploadform_left">
              <div style="text-align:right;	vertical-align:central;	">
                
              </div>
            </div>
            <div class="uploadform_right">
              <div style="text-align:left;	vertical-align:central;	">
                <input type="submit" name="btnInput" value="Daten importieren"/>
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
			
			// Formatieren der Telefonnummern
			function formatting($number){
				if ($number != ""){
					if (substr($number, 0, 2) == "+ "){
						$number = substr_replace ($number,"",1,1);
					}
					if (substr($number, 0, 2) == "41"){
						$number = substr_replace ($number,"+41",0,2);
					}
					if (substr($number, 0, 3) == "0 ("){
						$number = substr_replace ($number,"",0,3);
						$number = substr_replace ($number,"",4,1);
					}
					if (substr($number, 0, 5) == "(+41)"){ 
						if(substr($number, 6, 1) == "0"){
							$number = substr_replace ($number,"",0,6);
						}else{
							$number = str_replace ("(","",$number);
							$number = str_replace (")","",$number);	
						}
					}
					if (substr($number, 0, 2) == "00"){
						$number = substr_replace ($number,"+",0,2);
					}
					if (substr($number, 4, 3) == "(0)"){
						$number = substr_replace ($number,"",4,4);
					}
					// Enfernen der Non-Bracking Spaces
					$number = str_replace ("\xc2\xa0", "", $number);
					$number = str_replace ("-","",$number);
					$number = str_replace (" ","",$number);
					$number = str_replace ("/","",$number);
					$number = str_replace ("(0)","",$number);

					if (substr($number, 0, 1) == "0"){
						$number = substr_replace ($number,"+41",0,1);
					}
				}
				return $number;
			}

			// Aufbauen der verbindindung zur Datenbank
			$conn = new mysqli($servername, $username, $password, $db);

			// Prüfen ob die Verbindung zur Datenbank steht
			if ($conn->connect_error) {
			die("Verbindung fehlgeschlagen: " . $conn->connect_error);
			}
			// Prüfen ob der Button "btnInput" geklickt wurde
			try{
				if (isset($_POST['btnInput'])){
						// Abfragen der Dateiendung
						$filepath = @$_FILES["file"]["name"];
						$fileext = pathinfo($filepath, PATHINFO_EXTENSION);
						if($fileext == "xlsx" || $fileext == "xls"){
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
							}catch(PHPExcel_Reader_Exception $e) {
								die("<p class='error_message'>Fehler beim laden der Datei: ".$e->getMessage()."<p>");
							}
							// Laden der Worksheets
							foreach ($objPHPExcel->getWorksheetIterator() as $worksheet){
								$worksheetTitle     = $worksheet->getTitle();
								$highestRow         = $worksheet->getHighestRow(); // e.g. 10
								$highestColumn      = $worksheet->getHighestColumn(); // e.g 'F'
								$highestColumnIndex = PHPExcel_Cell::columnIndexFromString($highestColumn);
								$nrColumns = ord($highestColumn) - 64;
								// Abfragen des korrekten Worksheets
								if ($worksheetTitle == "Entreprise"){
									$worksheetError = false;
									$cell = $worksheet->getCellByColumnAndRow(5, 1);
									$label= $cell->getValue();
									$hasSpeedDial= ($label == "KurzwahlTel");
									echo $hasSpeedDial ? "Mit Kurzwahl" : "Ohne Kurzwahl";
									$companyCol= 1;
									$personCol= 2;
									$phoneCol= 4;
									$phoneSpeedDialCol= $hasSpeedDial ? 5 : -1;
									$mobileCol= $hasSpeedDial ? 6 : 5;
									$mobileSpeedDialCol= $hasSpeedDial ? 7 : -1;
									$emailCol=  $hasSpeedDial ? 9 : 7;
									
									// Laden der Zeilen und Spalten des Dokumentes
									for ($row = 2; $row <= $highestRow; ++ $row) 
									{
										$val=array();
										for ($col = 0; $col < $highestColumnIndex; ++$col) 
										{
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

										if ($hasSpeedDial)
										{
											$speeddial_phone = $val[$phoneSpeedDialCol];
											$speeddial_mobile = $val[$mobileSpeedDialCol];
										}
										$speeddial_phones[] = $speeddial_phone;
										$speeddial_mobiles[] = $speeddial_mobile;
										//var_dump($speeddial_phone);
										//var_dump($speeddial_mobile);
										
										if (is_numeric($phone) || is_numeric($mobile)){
											echo("<p>Zeile $row einfügen</p>");	
											$stmt->execute();
										}
										else
										{
											//echo("<p>Zeile $row hat keine Telefonnummern</p>");	
										}
									}
									echo("<p>Das Hochladen der Daten war erfolgreich</p>");	
								}
								if ($worksheetError == true){
									die("<p class='error_message'>Die ausgew&uaml;lte Datei muss ein Worksheet mit dem namen 'Entreprise' haben!</p>");
								}
							}
							$conn->close();
							$stmt->close();
						}else{
							die("<p class='error_message'>Es k&ouml;nnen nur Excel Dateien(.xlsx oder .xls) hochgeladen werden</p>");		
						}
					}
				}catch(PHPExcel_Exception $e){
					 die("<p class='error_message'>Fehler beim laden der Datei: ".$e->getMessage()."<p>");
				}
		  ?>
      </div>
      </form>
    </div>
    <table class="uploadedtable">
    	<tr>
      	<td colspan="5" class="uploadedtable_titel">    
        	Hochgeladene Daten
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
					for($ii = 0; $ii< count(@$companies);$ii++){
						$company = $companies[$ii];
						$person = $persons[$ii];
						$phone = $phones[$ii];
						$mobile = $mobiles[$ii];
						$speeddial_phone = $speeddial_phones[$ii];
						$mobile = $mobiles[$ii];
						$speeddial_mobile = $speeddial_mobiles[$ii];
						$email = $emails[$ii];
						if ($phone != "" || $mobile != ""){
							echo "<tr>";      	
							echo "<td class='uploadedtable_normal'>";
							echo $company;
							echo "</td>";
							echo "<td class='uploadedtable_normal'>";
							echo $person;
							echo "</td>";
							if($phone == ""){
								echo "<td class='uploadedtable_normal'>";
								echo $phone;
								echo "</td>";
							}else if(substr($phone, 0, 1) != "+") {
								echo "<td style=' '>";
								echo $phone;
								echo "</td>";
							}else if (is_numeric ($phone)  ){
								echo "<td class='uploadedtable_normal'>";
								echo $phone;
								echo "</td>";
							}else{
								echo "<td class='uploadedtable_notnormal'>";
								echo $mobile;
								echo "</td>";
							}
							echo "<td class='uploadedtable_normal'>";
							echo $speeddial_phone;
							echo "</td>";
							
							if($mobile == ""){
								echo "<td class='uploadedtable_normal'>";
								echo $mobile;
								echo "</td>";
							}else if(substr($mobile, 0, 1) != "+") {
								echo "<td class='uploadedtable_notnormal'>";
								echo $mobile;
								echo "</td>";
							}else if (is_numeric ($mobile)  ){
								echo "<td class='uploadedtable_normal'>";
								echo $mobile;
								echo "</td>";
							}else{
								echo "<td class='uploadedtable_notnormal'>";
								echo $mobile;
								echo "</td>";
							}
							echo "<td class='uploadedtable_normal'>";
							echo $speeddial_mobile;
							echo "</td>";

							if (strpos($email,"@")!==false || $email == ""){
								echo "<td class='uploadedtable_normal'>";
								echo $email;
								echo "</td>";
							} else {
								echo "<td class='uploadedtable_notnormal'>";
								echo $email;
								echo "</td>";	
							}
							echo"</tr>";
						}
				}
			?>
    </table>
	</body>
</html>