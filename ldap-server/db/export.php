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
    die("DB connection failed: " . $conn->connect_error);
}
$conn->set_charset('utf8');

/** Create a new PHPExcel Object **/
$objPHPExcel = new PHPExcel();
$objPHPExcel->getActiveSheet()->setTitle('Phonebook');

$objPHPExcel->getActiveSheet()->setCellValue('A1', 'Company');
$objPHPExcel->getActiveSheet()->setCellValue('B1', 'First name');
$objPHPExcel->getActiveSheet()->setCellValue('C1', 'Last name');
$objPHPExcel->getActiveSheet()->setCellValue('D1', 'Address');
$objPHPExcel->getActiveSheet()->setCellValue('E1', 'Zip');
$objPHPExcel->getActiveSheet()->setCellValue('F1', 'City');
$objPHPExcel->getActiveSheet()->setCellValue('G1', 'Country');
$objPHPExcel->getActiveSheet()->setCellValue('H1', 'Phone');
$objPHPExcel->getActiveSheet()->setCellValue('I1', 'KW phone');
$objPHPExcel->getActiveSheet()->setCellValue('J1', 'Mobile');
$objPHPExcel->getActiveSheet()->setCellValue('K1', 'KW mobile');
$objPHPExcel->getActiveSheet()->setCellValue('L1', 'Home');
$objPHPExcel->getActiveSheet()->setCellValue('M1', 'KW Home');
$objPHPExcel->getActiveSheet()->setCellValue('N1', 'Fax');
$objPHPExcel->getActiveSheet()->setCellValue('O1', 'E-Mail');
$myRow= 1;
$res = $conn->query("select * from address ");
while ($row = $res->fetch_assoc()) {
    $myRow+= 1;
    $objPHPExcel->getActiveSheet()->setCellValue('A'.$myRow, $row['company']);
    $objPHPExcel->getActiveSheet()->setCellValue('B'.$myRow, $row['firstname']);
    $objPHPExcel->getActiveSheet()->setCellValue('C'.$myRow, $row['lastname']);
    $objPHPExcel->getActiveSheet()->setCellValue('D'.$myRow, $row['address']);
    $objPHPExcel->getActiveSheet()->setCellValue('E'.$myRow, $row['zip']);
    $objPHPExcel->getActiveSheet()->setCellValue('F'.$myRow, $row['city']);
    $objPHPExcel->getActiveSheet()->setCellValue('G'.$myRow, $row['country']);
    $objPHPExcel->getActiveSheet()->setCellValue('H'.$myRow, $row['phone']);
    $objPHPExcel->getActiveSheet()->setCellValue('I'.$myRow, $row['speeddial_phone']);
    $objPHPExcel->getActiveSheet()->setCellValue('J'.$myRow, $row['mobile']);
    $objPHPExcel->getActiveSheet()->setCellValue('K'.$myRow, $row['speeddial_mobile']);
    $objPHPExcel->getActiveSheet()->setCellValue('L'.$myRow, $row['home']);
    $objPHPExcel->getActiveSheet()->setCellValue('M'.$myRow, $row['speeddial_home']);
    $objPHPExcel->getActiveSheet()->setCellValue('N'.$myRow, $row['fax']);
    $objPHPExcel->getActiveSheet()->setCellValue('O'.$myRow, $row['email']); 
}

$objWriter = new PHPExcel_Writer_Excel2007($objPHPExcel);
header('Content-type: application/vnd.openxmlformats-officedocument.spreadsheetml.??sheet');
header('Content-Disposition: attachment; filename="phonebook.xlsx"');
$objWriter->save('php://output');

