<?php
// Definierten der include Dateien
require 'PHPExcel.php';
require_once 'PHPExcel/IOFactory.php';

// Definieren der Variabel
$servername = "127.0.0.1";
$username = "inno-ldap-db";
$password = "<password>";
$db = "phonebook_innovaphone";
$conn = new mysqli($servername, $username, $password, $db);

// Prüfen ob die Verbindung zur Datenbank steht
if ($conn->connect_error) {
    die("Verbindung fehlgeschlagen: " . $conn->connect_error);
}
/** Create a new PHPExcel Object **/
$objPHPExcel = new PHPExcel();
$objPHPExcel->getActiveSheet()->setTitle('Entreprise');

$objPHPExcel->getActiveSheet()->setCellValue('A1', 'Etat');
$objPHPExcel->getActiveSheet()->setCellValue('B1', 'Entreprise');
$objPHPExcel->getActiveSheet()->setCellValue('C1', 'Personne');
$objPHPExcel->getActiveSheet()->setCellValue('D1', 'Fonction');
$objPHPExcel->getActiveSheet()->setCellValue('E1', 'Tel');
$objPHPExcel->getActiveSheet()->setCellValue('F1', 'KurzwahlTel');
$objPHPExcel->getActiveSheet()->setCellValue('G1', 'Mobile');
$objPHPExcel->getActiveSheet()->setCellValue('H1', 'KurzwahlMobile');
$objPHPExcel->getActiveSheet()->setCellValue('I1', 'Fax');
$objPHPExcel->getActiveSheet()->setCellValue('J1', 'E-Mail');
$objPHPExcel->getActiveSheet()->setCellValue('K1', 'Adresse');
$objPHPExcel->getActiveSheet()->setCellValue('L1', 'Ville');
$objPHPExcel->getActiveSheet()->setCellValue('M1', 'Case Postale');
$objPHPExcel->getActiveSheet()->setCellValue('N1', 'Pays');
$myRow= 1;
$res = $conn->query("select * from address ");
while ($row = $res->fetch_assoc()) {
    $myRow+= 1;
    $objPHPExcel->getActiveSheet()->setCellValue('B'.$myRow, $row['company']);
    $objPHPExcel->getActiveSheet()->setCellValue('C'.$myRow, $row['person']);
    $objPHPExcel->getActiveSheet()->setCellValue('E'.$myRow, $row['phone']);
    $objPHPExcel->getActiveSheet()->setCellValue('F'.$myRow, $row['speeddial_phone']);
    $objPHPExcel->getActiveSheet()->setCellValue('G'.$myRow, $row['mobil']);
    $objPHPExcel->getActiveSheet()->setCellValue('H'.$myRow, $row['speeddial_mobile']);
    $objPHPExcel->getActiveSheet()->setCellValue('J'.$myRow, $row['email']);
}

$objWriter = new PHPExcel_Writer_Excel2007($objPHPExcel);
header('Content-type: application/vnd.openxmlformats-officedocument.spreadsheetml.??sheet');
header('Content-Disposition: attachment; filename="phonebook.xlsx"');
$objWriter->save('php://output');

