#!/bin/bash
##########################################################
############# KERBEROS AUTO CONFIGURATION ################
##########################################################
####### ** YOU MUST INSTALL krb5-server ** ###############
read -p "Enter your domain name(default example.com):" dmn
echo 
read -p "Enter your realm (default EXAMPLE.COM):" DMN
echo
read -p "Enter your kerberos server name(default kdc.example.com):" kd
echo
read -p "Enter your admin_server name(default kdc.example.com):" ad
echo "" > /etc/krb5.conf 
cat <<EOT > /etc/krb5.conf
[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log

[libdefaults]
 dns_lookup_realm = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 rdns = false
 default_realm = $DMN
 default_ccache_name = KEYRING:persistent:%{uid}

[realms]
 $DMN = {
  kdc = $kd
  admin_server = $ad
 }

[domain_realm]
 .$dmn = $DMN
 $dmn = $DMN
EOT
###############################################################
echo "" > /var/kerberos/krb5kdc/kdc.conf
cat <<EOT > /var/kerberos/krb5kdc/kdc.conf
[kdcdefaults]
 kdc_ports = 88
 kdc_tcp_ports = 88

[realms]
 $DMN = {
  #master_key_type = aes256-cts
  acl_file = /var/kerberos/krb5kdc/kadm5.acl
  dict_file = /usr/share/dict/words
  admin_keytab = /var/kerberos/krb5kdc/kadm5.keytab
  supported_enctypes = aes256-cts:normal aes128-cts:normal des3-hmac-sha1:normal arcfour-hmac:normal camellia256-cts:normal camellia128-cts:normal des-hmac-sha1:normal des-cbc-md5:normal des-cbc-crc:normal
 }
EOT
###############################################################
echo "" > /var/kerberos/krb5kdc/kadm5.acl # ACL
cat <<EOT > /var/kerberos/krb5kdc/kadm5.acl
*/admin@$DMN	*
EOT
###############################################################
read -p "Enter a password for Kerberos DB:" pas
kdb5_util create -P $pas -s -r $DMN # create kerberos DB
###############################################################
systemctl enable kadmin
systemctl enable krb5kdc
systemctl start kadmin
systemctl start krb5kdc
###############################################################
PS3='Please enter your choice: '
options=("Add Firewall Rule" "Disable Firewall")
select opt in "${options[@]}"
do
    case $opt in
        "Add Firewall Rule")
            firewall-cmd --permanent --add-service=kerberos
            firewall-cmd --reload
	    break;
            ;;
        "Disable Firewall")
            systemctl stop firewalld
            systemctl disable firewalld
            break;
	    ;;
        *) echo Invalid Option;;
    esac
done
###############################################################
kadmin.local -q "addprinc -pw $pas root/admin"
PS3='Please enter your choice: '
options=("Add host/user" "Proceed")
select opt in "${options[@]}"
do
    case $opt in
        "Add host/user")
	 read -p "Enter Host name(Ex: client1):" comp
	 kadmin.local -q "addprinc -randkey host/$comp.$dmn"
	 kadmin.local -q "ktadd -k /tmp/$comp.keytab host/$comp.$dmn "
 	 scp -r /etc/krb5.conf /tmp/$comp.keytab $comp:/tmp
            ;;
        "Proceed")
            break;
            ;;
        *) echo Invalid Option;;
    esac
done
###############################################################

