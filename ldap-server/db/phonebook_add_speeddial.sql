USE `phonebook_innovaphone`;
ALTER TABLE `address`
	ADD COLUMN `speeddial_mobile` VARCHAR(50) NULL AFTER `email`,
	ADD COLUMN `speeddial_phone` VARCHAR(50) NULL AFTER `speeddial_mobile`;

ALTER TABLE `address`
	ADD PRIMARY KEY `addressId` (`addressId`);
	
