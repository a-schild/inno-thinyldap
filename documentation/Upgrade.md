# Upgrade instructions

This new version adds support for speel dial functionality

## Upgrade to Innovaphone v13 or v14
- Make sure to modify the settings to include the new metaSearchXXXX attributes
  in the pbx and ldap query settings
  Meta Name Attribute metaSearchText
  Meta Number Attribute metaSearchNumber
  ![PBX settings](inno-pbx-config.png)
  

## Upgrade from 2.2 to 2.6
- make sure to replace InnoLdapServer.pm and inno-ldap.pl

## Upgrade from 2.1 to 2.2:
- The db connection info for the PHP part is now in a separate file includes/dbconn.inc.php
  No longer needed to modify index.php and export.php
  
## Upgrade from 1.x to 2.0 and 2.1 version:
- Please export your data in a excel file and then recreate the database
  with the phonebook.sql script
  Then change the exported data to match the new column layout
  and import them back
- Remove the old script.php file, it's no longer used (Used index.php instead)
- Make sure to replace all ldap attributes in all ldap settings your have,
  with exception of the quick dial entries
  Name Attributes: company,givenName,sn
  Number Attributes: telephoneNumber,mobile,homePhone
  Detail Attributes: mail,postalAddress,postalCode,l,countryCode

## Upgrade from 1.7 to 1.8 version:
- Make sure your MySQL database is using utf8mb4 encoding otherwise you will see encoding problems
  You might first export the data to excel, recreate the database and import the excel file again

## Upgrade from 1.3 to 1.x version:
- Nothing special, just make sure to copy over all config settings

## Upgrade from 1.2 to 1.3 version:
- Install the perl pid library
  apt-get install libfile-pid-perl

To upgrade place these new files on the LinuxPA
- InnoLdapServer.pm (Don't forget to change login config)
- inno-ldap and inno-ldap.pl
  
## Upgrade from initial (1.0) to the 1.1 version:

To upgrade place these new files on the LinuxPA

- InnoLdapServer.pm (Don't forget to change login config)
- script.php  (Don't forget to change login config)

- Update the DB structure with two new fields
  mysql -u root
  source /var/www/innovaphone/apps/phonebook/phonebook_add_speeddial.sql
  exit

- Set PHP rights for DB web gui
  chown www-data:www-data /var/www/innovaphone/apps/phonebook -R
- Install php5 mysql libraries
  apt-get install php5-mysql  php-http
  
- Test the php script
  Enter http://<lapgv-ip>/apps/phonebook/script.php in a webbrowser
  Upload the testdata.xlsx file, it should show the imported addresses on the bottom of the screen
  The new testdata.xlsx has two new fields for the speed dial of phones and mobiles
  
  
On the PBX you have to configure the external LDAP service like this:
- IP of your LinuxAP
- Port 389 (Sorry, no TLS yet)
- Username & Password
- Search base dc=company,dc=ch
- Mode basic
Name Attributes cn
Number Attributes telephoneNumber
Detail Attributes cn
