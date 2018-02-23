-- --------------------------------------------------------
-- Host:                         127.0.0.1
-- Server Version:               10.0.17-MariaDB - mariadb.org binary distribution
-- Server Betriebssystem:        Win64
-- HeidiSQL Version:             9.1.0.4867
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8mb4 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;

-- Exportiere Datenbank Struktur für phonebook_innovaphone
DROP DATABASE IF EXISTS `phonebook_innovaphone`;
CREATE DATABASE IF NOT EXISTS `phonebook_innovaphone` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `phonebook_innovaphone`;


-- Exportiere Struktur von Tabelle phonebook_innovaphone.address
DROP TABLE IF EXISTS `address`;
CREATE TABLE IF NOT EXISTS `address` (
  `addressId` int(11) NOT NULL AUTO_INCREMENT,
  `company` varchar(50) DEFAULT NULL,
  `person` varchar(50) DEFAULT NULL,
  `phone` varchar(50) DEFAULT NULL,
  `mobil` varchar(50) DEFAULT NULL,
  `speeddial_phone` varchar(50) DEFAULT NULL,
  `speeddial_mobile` varchar(50) DEFAULT NULL,
  `email` varchar(50) DEFAULT NULL,
  PRIMARY KEY `addressId` (`addressId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Daten Export vom Benutzer nicht ausgewählt
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IF(@OLD_FOREIGN_KEY_CHECKS IS NULL, 1, @OLD_FOREIGN_KEY_CHECKS) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
