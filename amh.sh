#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

clear;
echo '================================================================';
echo ' [LNMP/Nginx] Amysql Host - AMH 3.1.2 Strengthen version';
echo ' http://www.mf8.biz';
echo '================================================================';


# VAR ***************************************************************************************
AMHDir='/home/amh_install/';
SysName='';
SysBit='';
Cpunum='';
RamTotal='';
RamSwap='';
InstallModel='';
Domain=`ifconfig  | grep 'inet addr:'| grep -v '127.0.0.*' | cut -d: -f2 | awk '{ print $1}'`;
MysqlPass='';
AMHPass='';
StartDate='';
StartDateSecond='';
PHPDisable='';

# Version
AMSVersion='ams-1.5.0107-02';
AMHVersion='amh-3.1';
LibiconvVersion='libiconv-1.14';
LibmcryptVersion='libmcrypt-2.5.8';
MhashVersion='mhash-0.9.9.9';
McryptVersion='mcrypt-2.6.8';
MysqlVersion='mariadb-5.5.30';
PhpVersion='php-5.4.13';
NginxVersion='tengine-1.4.4';
PureFTPdVersion='pure-ftpd-1.0.36';

# Function List  *****************************************************************************
function CheckSystem()
{
	if [ $(id -u) != '0' ]; then
		echo '[Error] Please use root to install AMH.';
		exit;
	fi;
	
	egrep -i "centos" /etc/issue && SysName='centos';
	egrep -i "debian" /etc/issue && SysName='debian';
	egrep -i "ubuntu" /etc/issue && SysName='ubuntu';
	if [ "$SysName" == ''  ]; then
		echo '[Error] Your system is not supported install AMH.';
		exit;
	fi;

	SysBit='32';
	if [ `getconf WORD_BIT` == '32' ] && [ `getconf LONG_BIT` == '64' ]; then
		SysBit='64';
	fi;

	Cpunum=`cat /proc/cpuinfo |grep 'processor'|wc -l`;
	RamTotal=`free -m | grep 'Mem' | awk '{print $2}'`;
	RamSwap=`free -m | grep 'Swap' | awk '{print $2}'`;
	echo "Server ${Domain}";
	echo "${SysBit}Bit, ${Cpunum}*CPU, ${RamTotal}MB*RAM, ${RamSwap}MB*Swap";
	echo '================================================================';
	
	RamSum=$[$RamTotal+$RamSwap];
	if [ "$SysBit" == '32' ] && [ "$RamSum" -lt '250' ]; then
		echo -e "[Error] Not enough memory install AMH. \n(32bit system need memory: ${RamTotal}MB*RAM + ${RamSwap}MB*Swap > 250MB)";
		exit;
	elif [ "$SysBit" == '64' ];  then
		if [ "$RamSum" -lt '600' ]; then
			echo -e "[Error] Not enough memory install AMH. \n(64bit system need memory: ${RamTotal}MB*RAM + ${RamSwap}MB*Swap > 600MB)";
			if [ "$RamSum" -gt '250' ]; then
				echo "[Notice] Please use 32bit system.";
			fi;
			exit;
		fi;
	fi;
	
	if [ "$RamSum" -lt '380' ]; then
		PHPDisable='--disable-fileinfo';
	fi;
}

function ConfirmInstall()
{
	echo "[Notice] Confirm Install/Uninstall AMH? please select: (1~3)"
	select selected in 'Install AMH 3.1' 'Uninstall AMH 3.1' 'Exit'; do
		break;
	done;
	if [ "$selected" == 'Exit' ]; then
		echo 'Exit Install.';
		exit;
	elif [ "$selected" == 'Install AMH 3.1' ]; then
		InstallModel='1';
	elif [ "$selected" == 'Uninstall AMH 3.1' ]; then
		Uninstall;
	else
		ConfirmInstall;
		return;
	fi;

	echo "[OK] You Selected: ${selected}";
}

function InputDomain()
{
	if [ "$Domain" == '' ]; then
		echo '[Error] empty server ip.';
		read -p '[Notice] Please input server ip:' Domain;

		if [ "$Domain" == '' ]; then
			InputDomain;
		fi;
	fi;

	if [ "$Domain" != '' ]; then
		echo '[OK] Your server ip is:';
		echo $Domain;
	fi;
}


function InputMysqlPass()
{
	read -p '[Notice] Please input MySQL password:' MysqlPass;
	if [ "$MysqlPass" == '' ]; then
		echo '[Error] MySQL password is empty.';
		InputMysqlPass;
	else
		echo '[OK] Your MySQL password is:';
		echo $MysqlPass;
	fi;
}


function InputAMHPass()
{
	read -p '[Notice] Please input AMH password:' AMHPass;
	if [ "$AMHPass" == '' ]; then
		echo '[Error] AMH password empty.';
		InputAMHPass;
	else
		echo '[OK] Your AMH password is:';
		echo $AMHPass;
	fi;
}


function Timezone()
{
	rm -rf /etc/localtime;
	ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime;

	echo '[ntp Installing] ******************************** >>';
	if [ "$SysName" == 'centos' ]; then
		yum install -y ntp;
	else
		apt-get install -y ntpdate;
	fi;
	ntpdate -u pool.ntp.org;
	StartDate=$(date);
	StartDateSecond=$(date +%s);
	echo "Start time: ${StartDate}";
}


function CloseSelinux()
{
	if [ -s /etc/selinux/config ]; then
		sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config;
	fi;
}

function DeletePackages()
{
	if [ "$SysName" == 'centos' ]; then
		yum -y remove httpd;
		yum -y remove php;
		yum -y remove mysql-server mysql;
		yum -y remove php-mysql;
	else
		apt-get --purge remove nginx
		apt-get --purge remove mysql-server;
		apt-get --purge remove mysql-common;
		apt-get --purge remove php;
	fi;
}

function InstallBasePackages()
{
	if [ "$SysName" == 'centos' ]; then
		echo '[yum-fastestmirror Installing] ************************************************** >>';
		yum -y install yum-fastestmirror;

		cp /etc/yum.conf /etc/yum.conf.lnmp
		sed -i 's:exclude=.*:exclude=:g' /etc/yum.conf
		for packages in gcc gcc-c++ ncurses-devel libxml2-devel openssl-devel curl-devel libjpeg-devel libpng-devel autoconf pcre-devel libtool-libs freetype-devel gd zlib-devel zip unzip wget crontabs iptables file bison cmake patch mlocate flex diffutils automake make  readline-devel  glibc-devel glibc-static glib2-devel  bzip2-devel gettext-devel libcap-devel logrotate ftp openssl expect; do 
			echo "[${packages} Installing] ************************************************** >>";
			yum -y install $packages; 
		done;
		mv -f /etc/yum.conf.lnmp /etc/yum.conf;
	else
		apt-get remove -y apache2 apache2-doc apache2-utils apache2.2-common apache2.2-bin apache2-mpm-prefork apache2-doc apache2-mpm-worker mysql-client mysql-server mysql-common php;
		killall apache2;
		apt-get update;
		for packages in build-essential gcc g++ cmake make ntp logrotate automake patch autoconf autoconf2.13 re2c wget flex cron libzip-dev libc6-dev rcconf bison cpp binutils unzip tar bzip2 libncurses5-dev libncurses5 libtool libevent-dev libpcre3 libpcre3-dev libpcrecpp0 libssl-dev zlibc openssl libsasl2-dev libxml2 libxml2-dev libltdl3-dev libltdl-dev zlib1g zlib1g-dev libbz2-1.0 libbz2-dev libglib2.0-0 libglib2.0-dev libpng3 libfreetype6 libfreetype6-dev libjpeg62 libjpeg62-dev libjpeg-dev libpng-dev libpng12-0 libpng12-dev curl libcurl3  libpq-dev libpq5 gettext libcurl4-gnutls-dev  libcurl4-openssl-dev libcap-dev ftp openssl expect; do
			echo "[${packages} Installing] ************************************************** >>";
			apt-get install -y $packages --force-yes;apt-get -fy install;apt-get -y autoremove; 
		done;
	fi;
}


function Downloadfile()
{
	randstr=$(date +%s);
	cd $AMHDir/packages;

	if [ -s $1 ]; then
		echo "[OK] $1 found.";
	else
		echo "[Notice] $1 not found, download now......";
		if ! wget -c --tries=3 ${2}?${randstr} ; then
			echo "[Error] Download Failed : $1, please check $2 ";
			exit;
		else
			mv ${1}?${randstr} $1;
		fi;
	fi;
}

function InstallReady()
{
	mkdir -p $AMHDir/conf;
	mkdir -p $AMHDir/packages/untar;
	chmod +Rw $AMHDir/packages;

	mkdir -p /root/amh/;
	chmod +Rw /root/amh;

	cd $AMHDir/packages;
	wget http://amysql.com/file/AMH/3.1/conf.zip;
	unzip conf.zip -d $AMHDir/conf;

	cd $AMHDir/conf;
	wget http://amysql.com/file/AMH/3.1/bin/${SysName}${SysBit};
	mv ${SysName}${SysBit} amh;

}


# Install Function  *********************************************************

function Uninstall()
{
	read -p '[Notice] Confirm Uninstall(Delete All Data)? : (y/n)' confirmUN;
	if [ "$confirmUN" != 'y' ]; then
		exit;
	fi;

	killall nginx;
	killall mysqld;
	killall pure-ftpd;
	killall php-cgi;
	killall php-fpm;

	for line in `ls /root/amh/modules`; do
		amh module $line uninstall;
	done;
	rm -rf /etc/init.d/amh-start;
	rm -rf /usr/local/libiconv;
	rm -rf /usr/local/nginx/ ;
	rm -rf /usr/local/mysql/ /etc/my.cnf  /etc/ld.so.conf.d/mysql.conf /usr/bin/mysql /var/lock/subsys/mysql /var/spool/mail/mysql;
	rm -rf /usr/local/php/ /usr/lib/php /etc/php.ini /etc/php.d /usr/local/zend;
	rm -rf /home/wwwroot/;
	rm -rf /etc/pure-ftpd.conf /etc/pam.d/ftp /usr/local/sbin/pure-ftpd /etc/pureftpd.passwd /etc/amh-iptables;
	rm -rf /etc/logrotate.d/nginx /root/.mysqlroot;
	rm -rf /root/amh /bin/amh;
	rm -rf $AMHDir;

	if [ "$SysName" == 'centos' ]; then
		chkconfig amh-start off;
	else
		update-rc.d -f amh-start remove;
	fi;

	echo '[OK] Successfully uninstall AMH.';
	exit;
}

function InstallLibiconv()
{
	echo "[${LibiconvVersion} Installing] ************************************************** >>";
	Downloadfile "${LibiconvVersion}.tar.gz" "http://amysql-amh.googlecode.com/files/${LibiconvVersion}.tar.gz";
	rm -rf $AMHDir/packages/untar/$LibiconvVersion;
	echo "tar -zxf ${LibiconvVersion}.tar.gz ing...";
	tar -zxf $AMHDir/packages/$LibiconvVersion.tar.gz -C $AMHDir/packages/untar;

	if [ ! -d /usr/local/libiconv ]; then
		cd $AMHDir/packages/untar/$LibiconvVersion;
		./configure --prefix=/usr/local/libiconv;
		make;
		make install;
		echo "[OK] ${LibiconvVersion} install completed.";
	else
		echo '[OK] libiconv is installed!';
	fi;
}


function InstallMysql()
{
	# [dir] /usr/local/mysql/
	echo "[${MysqlVersion} Installing] ************************************************** >>";
	Downloadfile "${MysqlVersion}.tar.gz" "http://ftp.kaist.ac.kr/mariadb/mariadb-5.5.30/kvm-tarbake-jaunty-x86/${MysqlVersion}.tar.gz";
	rm -rf $AMHDir/packages/untar/$MysqlVersion;
	echo "tar -zxf ${MysqlVersion}.tar.gz ing...";
	tar -zxf $AMHDir/packages/$MysqlVersion.tar.gz -C $AMHDir/packages/untar;

	if [ ! -d /usr/local/mysql ]; then
		cd $AMHDir/packages/untar/$MysqlVersion;
		groupadd mysql;
		useradd -s /sbin/nologin -g mysql mysql;
		cmake -DCMAKE_INSTALL_PREFIX=/usr/local/mysql  -DDEFAULT_CHARSET=utf8 -DDEFAULT_COLLATION=utf8_general_ci -DWITH_EXTRA_CHARSETS=complex -DWITH_READLINE=1 -DENABLED_LOCAL_INFILE=1;
		#http://forge.mysql.com/wiki/Autotools_to_CMake_Transition_Guide
		make -j $Cpunum;
		make install;
		chmod +w /usr/local/mysql;
		chown -R mysql:mysql /usr/local/mysql;

		cp $AMHDir/conf/my.cnf /etc/my.cnf;
		cp $AMHDir/conf/mysql /root/amh/mysql;
		chmod +x /root/amh/mysql;
		/usr/local/mysql/scripts/mysql_install_db --user=mysql --defaults-file=/etc/my.cnf --basedir=/usr/local/mysql --datadir=/usr/local/mysql/data;
		

# EOF **********************************
cat > /etc/ld.so.conf.d/mysql.conf<<EOF
/usr/local/mysql/lib/mysql
/usr/local/lib
EOF
# **************************************

		ldconfig;
		if [ "$SysBit" == '64' ] ; then
			ln -s /usr/local/mysql/lib/mysql /usr/lib64/mysql;
		else
			ln -s /usr/local/mysql/lib/mysql /usr/lib/mysql;
		fi;
		chmod 775 /usr/local/mysql/support-files/mysql.server;
		/usr/local/mysql/support-files/mysql.server start;
		ln -s /usr/local/mysql/bin/mysql /usr/bin/mysql;
		ln -s /usr/local/mysql/bin/mysqladmin /usr/bin/mysqladmin;
		/usr/local/mysql/bin/mysqladmin password $MysqlPass;
		rm -rf /usr/local/mysql/data/test;

# EOF **********************************
mysql -hlocalhost -uroot -p$MysqlPass <<EOF
USE mysql;
DELETE FROM user WHERE user='';
UPDATE user set password=password('$MysqlPass') WHERE user='root';
DELETE FROM user WHERE not (user='root');
DROP USER ''@'%';
FLUSH PRIVILEGES;
EOF
# **************************************
		echo "[OK] ${MysqlVersion} install completed.";
	else
		echo '[OK] MySQL is installed.';
	fi;

}

function InstallPhp()
{
	# [dir] /usr/local/php
	echo "[${PhpVersion} Installing] ************************************************** >>";
	Downloadfile "${PhpVersion}.tar.gz" "http://us1.php.net/distributions/${PhpVersion}.tar.gz";
	rm -rf $AMHDir/packages/untar/$PhpVersion;
	echo "tar -zxf ${PhpVersion}.tar.gz ing...";
	tar -zxf $AMHDir/packages/$PhpVersion.tar.gz -C $AMHDir/packages/untar;

	if [ ! -d /usr/local/php ]; then
		cd $AMHDir/packages/untar/$PhpVersion;
		groupadd www;
		useradd -s /sbin/nologin -g www www;
		if [ "$InstallModel" == '1' ]; then
			./configure --prefix=/usr/local/php --enable-fpm --with-fpm-user=www --with-fpm-group=www --with-config-file-path=/etc --with-config-file-scan-dir=/etc/php.d --with-openssl --with-zlib  --with-curl --enable-ftp --with-gd --with-jpeg-dir --with-png-dir --with-freetype-dir --enable-gd-native-ttf --enable-mbstring --enable-zip --with-iconv=/usr/local/libiconv --with-mysql=/usr/local/mysql --without-pear $PHPDisable;
		fi;
		make -j $Cpunum;
		make install;
		
		cp $AMHDir/conf/php.ini /etc/php.ini;
		cp $AMHDir/conf/php /root/amh/php;
		cp $AMHDir/conf/php-fpm.conf /usr/local/php/etc/php-fpm.conf;
		cp $AMHDir/conf/php-fpm-template.conf /usr/local/php/etc/php-fpm-template.conf;
		chmod +x /root/amh/php;
		mkdir /etc/php.d;
		mkdir /usr/local/php/etc/fpm;
		mkdir /usr/local/php/var/run/pid;
		touch /usr/local/php/etc/fpm/amh.conf;
		/usr/local/php/sbin/php-fpm;

		echo "[OK] ${PhpVersion} install completed.";
	else
		echo '[OK] PHP is installed.';
	fi;
}

function InstallNginx()
{
	# [dir] /usr/local/nginx
	echo "[${NginxVersion} Installing] ************************************************** >>";
	Downloadfile "${NginxVersion}.tar.gz" "http://tengine.taobao.org/download/${NginxVersion}.tar.gz";
	rm -rf $AMHDir/packages/untar/$NginxVersion;
	echo "tar -zxf ${NginxVersion}.tar.gz ing...";
	tar -zxf $AMHDir/packages/$NginxVersion.tar.gz -C $AMHDir/packages/untar;

	if [ ! -d /usr/local/nginx ]; then
		cd $AMHDir/packages/untar/$NginxVersion;
		./configure --prefix=/usr/local/nginx --user=www --group=www --with-http_ssl_module  --with-http_gzip_static_module --without-mail_pop3_module --without-mail_imap_module --without-mail_smtp_module --without-http_uwsgi_module --without-http_scgi_module ;
		make -j $Cpunum;
		make install;

		mkdir -p /home/wwwroot/index /home/backup /usr/local/nginx/conf/vhost/  /usr/local/nginx/conf/vhost_stop/  /usr/local/nginx/conf/rewrite/;
		chown +w /home/wwwroot/index;
		touch /usr/local/nginx/conf/rewrite/amh.conf;


		cp $AMHDir/conf/nginx.conf /usr/local/nginx/conf/nginx.conf;
		cp $AMHDir/conf/nginx-host.conf /usr/local/nginx/conf/nginx-host.conf;
		cp $AMHDir/conf/fcgi.conf /usr/local/nginx/conf/fcgi.conf;
		cp $AMHDir/conf/fcgi-host.conf /usr/local/nginx/conf/fcgi-host.conf;
		cp $AMHDir/conf/nginx /root/amh/nginx;
		cp $AMHDir/conf/host /root/amh/host;
		chmod +x /root/amh/nginx;
		chmod +x /root/amh/host;
		sed -i 's/www.amysql.com/'$Domain'/g' /usr/local/nginx/conf/nginx.conf;

		cd /home/wwwroot/index;
		mkdir -p tmp etc/rsa bin usr/sbin log;
		chown mysql:mysql etc/rsa;
		chmod 777 tmp;
		cp /etc/hosts /etc/resolv.conf /etc/nsswitch.conf etc/;
		if [ "$SysBit" == '64' ]; then
			mkdir lib64;
			(\cp /lib64/{ld-linux-x86-64.so.2,libc.so.6,libdl.so.2,libnss_dns.so.2,libnss_files.so.2,libresolv.so.2,libtermcap.so.2} lib64/) 2> /dev/null;
		else
			mkdir lib;
			(\cp /lib/{ld-linux.so.2,libc.so.6,libdl.so.2,libnss_dns.so.2,libnss_files.so.2,libresolv.so.2,libtermcap.so.2} lib/) 2> /dev/null;
		fi;

		/usr/local/nginx/sbin/nginx;
		/usr/local/php/sbin/php-fpm;

		echo "[OK] ${NginxVersion} install completed.";
	else
		echo '[OK] Nginx is installed.';
	fi;
}

function InstallPureFTPd()
{
	# [dir] /etc/	/usr/local/bin	/usr/local/sbin
	echo "[${PureFTPdVersion} Installing] ************************************************** >>";
	Downloadfile "${PureFTPdVersion}.tar.gz" "http://amysql-amh.googlecode.com/files/${PureFTPdVersion}.tar.gz";
	rm -rf $AMHDir/packages/untar/$PureFTPdVersion;
	echo "tar -zxf ${PureFTPdVersion}.tar.gz ing...";
	tar -zxf $AMHDir/packages/$PureFTPdVersion.tar.gz -C $AMHDir/packages/untar;

	if [ ! -f /etc/pure-ftpd.conf ]; then
		cd $AMHDir/packages/untar/$PureFTPdVersion;
		./configure --with-puredb --with-quotas --with-throttling --with-ratios --with-peruserlimits;
		make -j $Cpunum;
		make install;
		cp contrib/redhat.init /usr/local/sbin/redhat.init;
		chmod 755 /usr/local/sbin/redhat.init;

		cp $AMHDir/conf/pure-ftpd.conf /etc;
		cp configuration-file/pure-config.pl /usr/local/sbin/pure-config.pl;
		chmod 744 /etc/pure-ftpd.conf;
		chmod 755 /usr/local/sbin/pure-config.pl;
		/usr/local/sbin/redhat.init start;

		groupadd ftpgroup;
		useradd -d /home/wwwroot/ -s /sbin/nologin -g ftpgroup ftpuser;

		cp $AMHDir/conf/ftp /root/amh/ftp;
		chmod +x /root/amh/ftp;

		/sbin/iptables-save > /etc/amh-iptables;
		sed -i '/--dport 21 -j ACCEPT/d' /etc/amh-iptables;
		sed -i '/--dport 80 -j ACCEPT/d' /etc/amh-iptables;
		sed -i '/--dport 8888 -j ACCEPT/d' /etc/amh-iptables;
		sed -i '/--dport 10100:10110 -j ACCEPT/d' /etc/amh-iptables;
		/sbin/iptables-restore < /etc/amh-iptables;
		/sbin/iptables -I INPUT -p tcp --dport 21 -j ACCEPT;
		/sbin/iptables -I INPUT -p tcp --dport 80 -j ACCEPT;
		/sbin/iptables -I INPUT -p tcp --dport 8888 -j ACCEPT;
		/sbin/iptables -I INPUT -p tcp --dport 10100:10110 -j ACCEPT;
		/sbin/iptables-save > /etc/amh-iptables;
		echo 'IPTABLES_MODULES="ip_conntrack_ftp"' >>/etc/sysconfig/iptables-config;

		touch /etc/pureftpd.passwd;
		chmod 774 /etc/pureftpd.passwd;
		echo "[OK] ${PureFTPdVersion} install completed.";
	else
		echo '[OK] PureFTPd is installed.';
	fi;
}

function InstallAMH()
{
	# [dir] /home/wwwroot/index/web
	echo "[${AMHVersion} Installing] ************************************************** >>";
	Downloadfile "${AMHVersion}.tar.gz" "http://amysql-amh.googlecode.com/files/${AMHVersion}.tar.gz";
	rm -rf $AMHDir/packages/untar/$AMHVersion;
	echo "tar -xf ${AMHVersion}.tar.gz ing...";
	tar -xf $AMHDir/packages/$AMHVersion.tar.gz -C $AMHDir/packages/untar;

	if [ ! -d /home/wwwroot/index/web ]; then
		cp -r $AMHDir/packages/untar/$AMHVersion /home/wwwroot/index/web;

		cp $AMHDir/conf/amh /bin/amh;
		chmod 4775 /bin/amh;
		cp -a $AMHDir/conf/amh-backup.conf /home/wwwroot/index/etc;
		cp -a $AMHDir/conf/html /home/wwwroot/index/etc;
		cp $AMHDir/conf/backup /root/amh;
		cp $AMHDir/conf/revert /root/amh;
		cp $AMHDir/conf/BRssh /root/amh;
		cp $AMHDir/conf/BRftp /root/amh;
		cp $AMHDir/conf/info /root/amh;
		cp $AMHDir/conf/SetParam /root/amh;
		cp $AMHDir/conf/module /root/amh;
		cp -a $AMHDir/conf/modules /root/amh;
		chmod +x /root/amh/backup /root/amh/revert /root/amh/BRssh /root/amh/BRftp /root/amh/info /root/amh/SetParam /root/amh/module;

		sed -i "s/'localhost'/'127.0.0.1'/g" /home/wwwroot/index/web/Amysql/Config.php;
		sed -i "s/'MysqlPass'/'"$MysqlPass"'/g" /home/wwwroot/index/web/Amysql/Config.php;

		sed -i "s/'AMHPass_amysql-amh'/'"$AMHPass"_amysql-amh'/g" $AMHDir/conf/amh.sql;
		/usr/local/mysql/bin/mysql -u root -p$MysqlPass < $AMHDir/conf/amh.sql;

		echo "[OK] ${AMHVersion} install completed.";
	else
		echo '[OK] AMH is installed.';
	fi;
}

function InstallAMS()
{
	# [dir] /home/wwwroot/index/web/ams
	echo "[${AMSVersion} Installing] ************************************************** >>";
	Downloadfile "${AMSVersion}.tar.gz" "http://amysql-amh.googlecode.com/files/${AMSVersion}.tar.gz";
	rm -rf $AMHDir/packages/untar/$AMSVersion;
	echo "tar -xf ${AMSVersion}.tar.gz ing...";
	tar -xf $AMHDir/packages/$AMSVersion.tar.gz -C $AMHDir/packages/untar;

	if [ ! -d /home/wwwroot/index/web/ams ]; then
		cp -r $AMHDir/packages/untar/$AMSVersion /home/wwwroot/index/web/ams;
		chown www:www -R /home/wwwroot/index/web/ams/View/DataFile;

		sed -i "s/'localhost'/'127.0.0.1'/g" /home/wwwroot/index/web/ams/Amysql/Config.php;
		echo "[OK] ${AMSVersion} install completed.";
	else
		echo '[OK] AMS is installed.';
	fi;
}


# AMH Installing ****************************************************************************
CheckSystem;
ConfirmInstall;
InputDomain;
InputMysqlPass;
InputAMHPass;
Timezone;
CloseSelinux;
DeletePackages;
InstallBasePackages;
InstallReady;
InstallLibiconv;
InstallMysql;
InstallPhp;
InstallNginx;
InstallPureFTPd;
InstallAMH;
InstallAMS;


if [ -s /usr/local/nginx ] && [ -s /usr/local/php ] && [ -s /usr/local/mysql ]; then

cp $AMHDir/conf/amh-start /etc/init.d/amh-start;
chmod 775 /etc/init.d/amh-start;
if [ "$SysName" == 'centos' ]; then
	chkconfig --add amh-start;
	chkconfig amh-start on;
else
	update-rc.d -f amh-start defaults;
fi;
rm -rf $AMHDir;
/etc/init.d/amh-start;

echo '================================================================';
	echo '[AMH] Congratulations, AMH 3.1 install completed.';
	echo "AMH Management: http://${Domain}:8888";
	echo 'User:admin';
	echo "Password:${AMHPass}";
	echo "MySQL Password:${MysqlPass}";
	echo '';
	echo '******* SSH Management *******';
	echo 'Host: amh host';
	echo 'PHP: amh php';
	echo 'Nginx: amh nginx';
	echo 'MySQL: amh mysql';
	echo 'FTP: amh ftp';
	echo 'Backup: amh backup';
	echo 'Revert: amh revert';
	echo 'SetParam: amh SetParam';
	echo 'Module : amh module';
	echo 'Info: amh info';
	echo '';
	echo '******* View dirs *******';
	echo 'WebSite: /home/wwwroot';
	echo 'Nginx: /usr/local/nginx';
	echo 'PHP: /usr/local/php';
	echo 'MySQL: /usr/local/mysql';
	echo 'MySQL-Data: /usr/local/mysql/data';
	echo '';
	echo "Start time: ${StartDate}";
	echo "Completion time: $(date) (Use: $[($(date +%s)-StartDateSecond)/60] minute)";
	echo 'More help please visit:http://amysql.com';
echo '================================================================';
else
	echo 'Sorry, Failed to install AMH';
	echo 'Please contact us: http://amysql.com';
fi;
