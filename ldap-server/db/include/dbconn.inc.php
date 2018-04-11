<?php
$servername = "127.0.0.1";
$username = "inno-ldap-db";
$password = "<password>";
$db = "phonebook_innovaphone";

    $conn = mysqli_connect($servername, $username, $password, $db);

    # Wrong implementation in PHP versions prior to 5.2.9 and 5.3.0
    #if ($conn->connect_error) {
    #	    die("Connection failed: " . $conn->connect_error);
    #}
    if (mysqli_connect_error()) {
    die('Connect Error (' . mysqli_connect_errno() . ') '
            . mysqli_connect_error());
    }
    $conn->set_charset('utf8');
