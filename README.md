# FHEM NetworkDevice Module

## Description
This Repository holds modules for the integration of SNMP enabled network devices
like access points and switches into FHEM.

### Current Features
 * Fetch/Set standard SNMP values like sysName, sysContact, sysLocation
 * identify layer2 and/or layer3 network switches
  * Fetch port status (up, down), port names, port admin status
  * Fetch port statistics (nr of packets, errors, bytes)

### Planned Features
  * identify routers, dsl-modems, access points
  * fetch information and statistics from these devices
  * set some port status (admin-mode, duplex mode, vlan, etc.)

## Author

Dominik Meyer <dmeyer@federationhq.de>

## Installation

I only provide a debian example. If someone can provide others for Redhat, Gentoo, etc.
please send me a pull request.

### Debian requirements example

* apt-get install libsnmp-info-perl (all other requirements are installed with this)
* apt-get install snmp
* you require a decent version of snmp MIBs:
 - sudo mkdir /usr/local/netdisco
 - sudo git clone https://github.com/netdisco/netdisco-mibs.git /usr/local/netdisco/mibs
 - sudo cp /usr/local/netdisco/mibs/EXTRAS/contrib/snmp.conf /etc/snmp/
 - edit /etc/snmp/snmp.conf and deactivate all lines except for the vendor you own
 snmp enabled devices. _ref_, _net-snmp_ and _cisco_ should always stay enabled !
 * the last step can be ignored if you already have installed mibs into your system


### FHEM Module Installation

#### via Update
Use the following commands to add this repository to your FHEM installation and install all my modules.
* update add  https://raw.githubusercontent.com/byterazor/Fhem-NetworkDevice/master/controls_byterazor-fhem-networkdevice.txt
* update all https://raw.githubusercontent.com/byterazor/Fhem-NetworkDevice/master/controls_byterazor-fhem-networkdevice.txt

### FHEM device definition

  define switch NetworkDevice <ip-address | hostname>

## Module Documentation

_not yet available_

* download module to <FHEMDIR>/FHEM/
* cd <FHEMDIR>
* perl contrib/commandref_join.pl
* review your local commandref (http://<FHEMURL>/fhem/docs/commandref.html)

## Contributors

If you want to participate in the development of this module feel free to send me an email
or pull requests.

## License

All my modules are licensed under GPLv2.
