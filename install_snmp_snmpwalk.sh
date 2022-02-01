#!/usr/bin/env bash

create_snmp_config(){
	echo "configuration copy"
	cp /etc/snmp/snmpd.conf{,backup}
	read -p "please enter snmp password:" PASSWORD
	echo "com2sec AllUser  default                ${PASSWORD}" > /etc/snmp/snmpd.conf
	echo "group   AllGroup v2c           AllUser"  >> /etc/snmp/snmpd.conf
	echo 'access  AllGroup ""      any       noauth    exact  AllView none none'  >> /etc/snmp/snmpd.conf
	echo "view    AllView         included .1" >>  /etc/snmp/snmpd.conf
}

#RHEL 8 / CENTOS 8 SNMP install
echo "# snmp and tools install"
dnf install -y net-snmp
dnf install -y net-snmp-utils
echo "# autostart on boot"
systemctl enable snmpd
create_snmp_config
echo "# snmp start"
systemctl restart snmpd
echo "# snmp test OID sysName"
snmpwalk -v 2c -c ${PASSWORD} -O e 127.0.0.1 1.3.6.1.2.1.1.5 && echo "# test snmpwalk OK"
