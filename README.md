# inno-thinyldap
A very thiny LDAP service for Innovaphone PBX
It is intended to be installed on a LinuxAP
either running on a IPx11 Gateway or on a VM.

It could also be installed on any other Linux 
distribution, but this is not covered in the
documentation at the moment.

There are two components at the moment:
1. LDAP service to resolve phone numbers into addresses
2. (optional) a MySQL database with a small PHP GUI where
    you can upload your corporate address book as excel file

- For **installation** read the **install.txt** in documentation
- For **update** istructions read the **update.txt** in documentation

- v1.0 Initial public version
- v1.1 Added support for speed dial numbers
- v1.2 Added support for text search
- v1.3 Added support to correctly shutdown ldap daemon
- v1.4 Added support for LDAPS
- v1.5 Added support for Gigaset N510 and N720 DECT handsets
- v1.6 Remap umlauts for Gigaset N510 and N720 DECT handsets
       Added text search in gigaset environments
- v1.7 Added better support for Innovaphone DECT handsets
- v1.8 Better umlaut handling (utf8)
- v2.0 Added a lot of other fields, like home, zip, city etc.
       Improved Innovaphone DECT handling
- v2.1 Added missing homeXXXX DB fields
       Worked around a IP1200 DECT ldap query handling problem #9
- v2.2 Fixed problem with home and speeddail_home entries
	   Moved php db conenctionconfig in separate file
- v2.3 Corrected wrong mapping of fax->lastName in ldap results
- v2.4 Solved searching with non-ascii characters issue #6
       Cleanup logging issue #13
	   Fixed uninitialized message issue #8
- v2.5 Telsearch queries now also work when db lookups disabled issue #5
- v2.6 Drop privileges to daemon issue #2
       Use prefork for better performance

	 
(C) Aarboard AG, www.aarboard.ch, 2018

This project is under GNU Public License v3