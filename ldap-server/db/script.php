<?php
// Definierten der benötigten Dateien
require 'PHPExcel.php';
require_once 'PHPExcel/IOFactory.php';

// Definieren der Variabel
$servername = "127.0.0.1";
$username = "<db-login-username>";
$password = "<db-password>;
$db = "phonebook_innovaphone";
?>
<html>
	<head>
		<title>Import Excel File into MySQL</title>
    <link href="css/style.css" rel="stylesheet">
	</head>
	<body>
		
    <div class="uploadform">
    	<form action="" method="post" enctype="multipart/form-data">
        	<div class="uplaodform_titel">    
          	Import Excel File into MySQL
          </div> 
          <div class="uploadform_content">
          	<div class="uploadform_left">
          		<div style="text-align:right;	vertical-align:central;	">
         	 			Select file 
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
                Submit
              </div>
            </div>
            <div class="uploadform_right">
              <div style="text-align:left;	vertical-align:central;	">
                <input type="submit" name="btnInput" value="Import Data from Excel"/>
              </div>
            </div>
          </div>

      	<div class="uplaodform_errordisplay" >
<?php
              $company = "";
              $person = "";
              $phone = "";
              $mobile = "";
							$email = "";
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
											$stmt = $conn->prepare("insert ignore into address (company, person, phone, mobil, email) values(?,?,?,?,?)");
											$stmt->bind_param("sssss", $company, $person, $phone, $mobile, $email);
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
													// Laden der Zeilen und Spalten des Dokuements
													for ($row = 2; $row <= $highestRow; ++ $row) {
														$val=array();
														for ($col = 0; $col < $highestColumnIndex; ++ $col) {
																$cell = $worksheet->getCellByColumnAndRow($col, $row);
																$val[] = $cell->getValue();
														}
														// Speicher des Daten in die dafür vorgesehen Variabeln
														$company = $val[1];
														//$company = utf8_decode($company);
														$companys[] = $company;
														$person = $val[2];
														//$person = utf8_decode($person);
														$persons[] = $person;
														$phone = $val[4];
														$phone = formatting($phone);
														//$phone = utf8_decode($phone);
														$phones[] = $phone;
														$mobile = $val[5];
														$mobile = formatting($mobile);
														//$mobile = utf8_decode($mobile);
														$mobiles[] = $mobile;
														$email = $val[7];
														//$email = utf8_decode($email);
														$emails[] = $email;
														if (is_numeric($phone) || is_numeric($mobile)){
															$stmt->execute();
														}
													}
													echo("<p>Das Hochladen der Daten war erfolgreich	</p>");	
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
      	<td class="uploadedtable_header" width="40%">Company</td>
        <td class="uploadedtable_header" width="20%">Person</td>
        <td class="uploadedtable_header" width="10%">Phone</td>
        <td class="uploadedtable_header" width="10%">Mobile</td>
        <td class="uploadedtable_header" width="20%">Email</td>
      </tr>
      <?php
					for($ii = 0; $ii< count(@$companys);$ii++){
						$company = $companys[$ii];
						$person = $persons[$ii];
						$phone = $phones[$ii];
						$mobile = $mobiles[$ii];
						$email = $emails[$ii];
						if ($phone != "" || $mobile != ""){
							echo "<tr>";      	
							echo "<td width='40%' class='uploadedtable_normal'>";
							echo $company;
							echo "</td>";
							echo "<td width='20%' class='uploadedtable_normal'>";
							echo $person;
							echo "</td>";
							if($phone == ""){
								echo "<td width='10%' class='uploadedtable_normal'>";
								echo $phone;
								echo "</td>";
							}else if(substr($phone, 0, 1) != "+") {
								echo "<td width='10%' style=' '>";
								echo $phone;
								echo "</td>";
							}else if (is_numeric ($phone)  ){
								echo "<td width='10%' class='uploadedtable_normal'>";
								echo $phone;
								echo "</td>";
							}else{
								echo "<td width='10%' class='uploadedtable_notnormal'>";
								echo $mobile;
								echo "</td>";
							}
							if($mobile == ""){
								echo "<td width='10%' class='uploadedtable_normal'>";
								echo $mobile;
								echo "</td>";
							}else if(substr($mobile, 0, 1) != "+") {
								echo "<td width='10%' class='uploadedtable_notnormal'>";
								echo $mobile;
								echo "</td>";
							}else if (is_numeric ($mobile)  ){
								echo "<td width='10%' class='uploadedtable_normal'>";
								echo $mobile;
								echo "</td>";
							}else{
								echo "<td width='10%' class='uploadedtable_notnormal'>";
								echo $mobile;
								echo "</td>";
							}
							if (strpos($email,"@")!==false || $email == ""){
								echo "<td width='20%' class='uploadedtable_normal'>";
								echo $email;
								echo "</td>";
							} else {
								echo "<td width='20%' class='uploadedtable_notnormal'>";
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