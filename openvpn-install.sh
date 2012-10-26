#!/bin/bash
#OpenVPN Server on CentOS OpenVZ VPS Script by Yasyf Mohamedali (http://blog.yasyf.com/2012/08/01/openvpn-server-on-a-centos-openvz-vps)
#Adapted from various scripts around the net, including http://www.openvz.ca/blog/2010/11/18/setup-tuntap-openvpn-server-openvz-5-minutes/
#https://gist.github.com/3230440
tunstate=`cat /dev/net/tun`
	if [ "$tunstate" = "cat: /dev/net/tun: Permission denied" ]
	then 
	clear
	echo "Sorry, but it seems that TUN/TAP is not enabled on your VPS."
	exit
	fi
ip=`grep IPADDR /etc/sysconfig/network-scripts/ifcfg-venet0:0 | awk -F= '{print $2}'`
yum install -y gcc make rpm-build autoconf.noarch zlib-devel pam-devel openssl openssl-devel
cd /etc/yum.repos.d
wget http://repos.openvpn.net/repos/yum/conf/repos.openvpn.net-CentOS6-snapshots.repo
yum update
yum -y install openvpn
cd /etc/openvpn/
rsaLoc="$(cd /usr/share/doc/openvpn-2.*/easy-rsa/;pwd)/"
cp -R $rsaLoc /etc/openvpn/
cd /etc/openvpn/easy-rsa/2.0/
chmod +rwx *
source ./vars
echo "####################################"
echo "If you set a passphrase during this step you will need to"
echo "type a password each time openvpn starts."
echo "Accepting the default values (just press enter at each step) will also work."
echo "####################################"
./clean-all
./build-ca
./build-key-server server
./build-dh
cp keys/{ca.crt,ca.key,server.crt,server.key,dh1024.pem} /etc/openvpn/
echo "####################################"
echo "Accepting the default values (just press enter at each step) will also work."
echo "This is your client key, you may set a passphrase here but it's not required"
echo "If you do set a password here, you will need to enter it each time you use it on your machine to connect"
echo "####################################"
./build-key client1
cd keys/
client="
client
remote $ip 1194
dev tun
comp-lzo
ca ca.crt
cert client1.crt
key client1.key
route-delay 2
route-method exe
redirect-gateway def1
dhcp-option DNS 10.10.10.1
verb 3"
echo "$client" > $HOSTNAME.ovpn
tar czf openvpn-keys.tgz ca.crt ca.key client1.crt client1.csr client1.key $HOSTNAME.ovpn
mv openvpn-keys.tgz ~

ovpnsettings='
port 1194
proto tcp
dev tun
ca ca.crt
cert server.crt
key server.key
server 10.8.0.0 255.255.255.0
dh dh1024.pem
ifconfig-pool-persist ipp.txt
comp-lzo
keepalive 10 60
ping-timer-rem
persist-tun
persist-key
verb 1
mute 10
ccd-exclusive
push "route 10.8.0.0 255.255.255.0"
push "dhcp-option DNS 10.8.0.1"
push "redirect-gateway def1 bypass-dhcp"
ping-timer-rem
daemon'
echo "$ovpnsettings" > /etc/openvpn/openvpn.conf
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
iptables -A FORWARD -s 10.8.0.0/255.255.255.0 -j ACCEPT 
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT 
iptables -A -t nat POSTROUTING -s 10.8.0.0/255.255.255.0 -j SNAT --to-source $ip
iptables-save > /etc/sysconfig/iptables
sed -i 's/eth0/venet0/g' /etc/sysconfig/iptables
yum install dnsmasq
/etc/init.d/dnsmasq start
chkconfig dnsmasq on
/etc/init.d/openvpn start
chkconfig openvpn on
echo "OpenVPN has been installed
Download ~/openvpn-keys.tgz archive and open the .ovpn file inside it in an OpenVPN Client Application"
echo "Adapted and Published By Yasyf Mohamedali (http://www.yasyf.com) at http://blog.yasyf.com/coding/openvpn-server-on-a-centos-openvz-vps"
echo "If you found this useful, feel free to donate at http://blog.yasyf.com/donate"