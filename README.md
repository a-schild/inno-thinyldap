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

For **installation** read the **install.txt** document,
for **update** istructions read the **update.txt** document

- v1.0 Initial public version
- v1.1 Added support for speed dial numbers
- v1.2 Added support for text search
- v1.3 Added support to correctly shutdown ldap daemon
- v1.4 Added support for LDAPS
- v1.5 Added support for Gigaset N510 and N720 DECT handsets

(C) Aarboard AG, www.aarboard.ch, 2017

This project is under GNU Public License v3