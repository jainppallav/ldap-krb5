#!/bin/bash
###################################################
yum install openldap-servers openldap-clients migrationtools -y
cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
chown -R ldap. /var/lib/ldap
###################################################
read -p"Enter password for ldap: " pass
echo "$pass" > /root/lpd
slappasswd -T /root/lpd > /root/enpas
enpas=$(cat /root/enpas)
echo $enpas
rm -rfv /root/enpas
###################################################
cat << EOT >> /etc/openldap/slapd.d/cn=config/olcDatabase\=\{0\}config.ldif
olcRootPW:$enpas
EOT
###################################################
read -p "Enter dc (Ex:-google)" dc1
echo
read -p "Enter dc (Ex:- com)" dc2
sed -i "s/my-domain/$dc1/g" /etc/openldap/slapd.d/cn\=config/olcDatabase\=\{2\}hdb.ldif
sed -i "s/com/$dc2/g" /etc/openldap/slapd.d/cn\=config/olcDatabase\=\{2\}hdb.ldif
sed -i "10iolcRootPW: $pass" /etc/openldap/slapd.d/cn\=config/olcDatabase\=\{2\}hdb.ldif
####################################################
cat << EOT >> /etc/openldap/slapd.d/cn\=config/olcDatabase\=\{2\}hdb.ldif
olcAccess: {0}to attrs=userPassword by self write by dn.base="cn=Manager,dc=$dc1,dc=$dc2" write by anonymous auth by * none
olcAccess: {1}to * by dn.base="cn=Manager,dc=$dc1,dc=$dc2" write by self write by * read
EOT
#####################################################
sed -i "s/my-domain/$dc1/g" /etc/openldap/slapd.d/cn\=config/olcDatabase\=\{1\}monitor.ldif
sed -i "s/com/$dc2/g" /etc/openldap/slapd.d/cn\=config/olcDatabase\=\{1\}monitor.ldif
#####################################################
systemctl enable slapd
systemctl start slapd
#firewall-cmd --permanent --add-service=ldap
#firewall-cmd --reload
sleep 3
######################################################
cd /etc/openldap/schema
sleep 2
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
sleep 4
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
sleep 4
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
sleep 4
######################################################
cat << EOT >> /etc/openldap/slapd.d/cn\=config/base.ldif
dn: dc=$dc1,dc=$dc2
objectClass: dcObject
objectClass: organization
dc: $dc1
o : $dc1

dn: ou=People,dc=$dc1,dc=$dc2
objectClass: organizationalunit
ou: People

dn: ou=Group,dc=$dc1,dc=$dc2
objectClass: organizationalunit
ou: Group
EOT
cd /etc/openldap/slapd.d/cn\=config/
######################################################
ldapadd -x -D cn=Manager,dc=$dc1,dc=$dc2 -W -f base.ldif
######################################################
ldapsearch -x -D cn=Manager,dc=$dc1,dc=$dc2 -W -b dc=$dc1,dc=$dc2
######################################################
PS3='Please enter your choice: '
options=("Add User" "Proceed")
select opt in "${options[@]}"
do
    case $opt in
        "Add User")
	    read -p "Enter username:" usrn
            useradd $usrn
	    grep $usrn /etc/passwd >> /tmp/users
	    grep $usrn /etc/group >> /tmp/groups
	    ;;
        "Proceed")
            break;
            ;;
        *) echo Invalid Option;;
    esac
done
######################################################
cd /usr/share/migrationtools/
sed -i "s/padl.com/$dc1.$dc2/" migrate_common.ph
sed -i "s/dc=padl,dc=com/dc=$dc1,dc=$dc2/" migrate_common.ph
sed -i 's/$EXTENDED_SCHEMA = 0;/$EXTENDED_SCHEMA = 1;/' migrate_common.ph 
######################################################
./migrate_passwd.pl /tmp/users /tmp/users.ldif
sleep 3
./migrate_group.pl /tmp/groups /tmp/groups.ldif
######################################################
ldapadd -x -D cn=Manager,dc=$dc1,dc=$dc2 -W -f /tmp/groups.ldif
ldapadd -x -D cn=Manager,dc=$dc1,dc=$dc2 -W -f /tmp/users.ldif

