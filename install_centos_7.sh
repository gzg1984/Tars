#!/bin/bash

PWD_DIR=`pwd`
MachineIp=`ip -4 addr show eth0|grep inet|sed -e "s/inet \(.*\)\/24.*/\1/g"`
MachineName=$MachineIp
MysqlIncludePath=/usr/include/mysql
MysqlLibPath=/usr/lib64/mysql


##install compile tools & libs

yum install -y glibc-devel flex bison cmake ncurses-devel zlib-devel  perl perl-Module-Install.noarch    gcc gcc-c++ nasm psmisc wget
if [ -f framework/CMakeLists.txt ]
then
	echo "Framework exists..."
else
	git submodule update --init --recursive framework
fi

if [ -f /usr/bin/mysql ]
then
	echo "Mysql exists..."
else
	yum install -y mariadb mariadb-server mariadb-libs mariadb-devel 

	echo "Do mysql post install"
	id mysql
	if [ $? -eq "0" ]
	then
		echo "User mysql exist. Do not create it."
	else
		useradd mysql
	fi

	echo "Do mysql config install"
	#sed -i "s/    192.168.2.131/${MachineIp}/g" `grep     192.168.2.131 -rl ./build/conf/*`
	#cp /etc/my.cnf /etc/my.cnf.bak
	#cp ${PWD_DIR}/build/conf/my.cnf /etc/my.cnf

	echo "Start mysql on centos 7"
	mysql_install_db --user=mysql
	systemctl start mariadb.service

	## Set password for root
	echo "Modify Root Password"
	mysqladmin -u root password 'root@appinside'
	mysqladmin -u root -h ${MachineName} password 'root@appinside'

	echo "${MysqlLibPath}" >> /etc/ld.so.conf
	ldconfig

	##添加mysql的bin路径
	#echo "PATH=\$PATH:/usr/local/mysql/bin" >> /etc/profile
	#echo "export PATH" >> /etc/profile
	#source /etc/profile
mysql -uroot -proot@appinside -e "grant all on *.* to 'tars'@'%' identified by 'tars2015' with grant option;"
mysql -uroot -proot@appinside -e "grant all on *.* to 'tars'@'localhost' identified by 'tars2015' with grant option;"
mysql -uroot -proot@appinside -e "grant all on *.* to 'tars'@'${MachineName}' identified by 'tars2015' with grant option;"
mysql -uroot -proot@appinside -e "flush privileges;"

fi

echo "Init CMakeList file"
sed -i "s@/usr/local/mysql/include@${MysqlIncludePath}@g" ./framework/CMakeLists.txt
sed -i "s@/usr/local/mysql/lib@${MysqlLibPath}@g" ./framework/CMakeLists.txt
sed -i "s@/usr/local/mysql/include@${MysqlIncludePath}@g" ./framework/tarscpp/CMakeLists.txt
sed -i "s@/usr/local/mysql/lib@${MysqlLibPath}@g" ./framework/tarscpp/CMakeLists.txt




echo "================Start Build================"
cd ./framework/
patch -p1 < ../0001-modify-to-use-mysql.so.patch
cd -

cd ./framework/build/
chmod u+x build.sh
./build.sh all
./build.sh install
cd -

#exit 0

##Tars数据库环境初始化

echo "=================Sed in Framework Sql================"
cd ./framework/sql/
sed -i "s/    192.168.2.131/${MachineIp}/g" `grep     192.168.2.131 -rl ./*`
sed -i "s/    db.tars.com/${MachineIp}/g" `grep     db.tars.com -rl ./*`
chmod u+x exec-sql.sh
./exec-sql.sh
cd -

##打包框架基础服务
cd ./framework/build/
make framework-tar

make tarsstat-tar
make tarsnotify-tar
make tarsproperty-tar
make tarslog-tar
make tarsquerystat-tar
make tarsqueryproperty-tar
cd -

##安装核心基础服务
mkdir -p /usr/local/app/tars/
cp ./framework/build/framework.tgz /usr/local/app/tars/
cd /usr/local/app/tars
tar xzfv framework.tgz

sed -i "s/192.168.2.131/${MachineIp}/g" `grep     192.168.2.131 -rl ./*`
sed -i "s/    192.168.2.131/${MachineIp}/g" `grep     192.168.2.131 -rl ./*`
sed -i "s/registry.tars.com/${MachineIp}/g" `grep registry.tars.com -rl ./*`
sed -i "s/web.tars.com/${MachineIp}/g" `grep web.tars.com -rl ./*`

echo "here.............."`pwd`
echo "here.............."`pwd`
echo "here.............."`pwd`
echo "here.............."`pwd`
echo "here.............."`pwd`
echo "here.............."`pwd`

chmod u+x tars_install.sh
./tars_install.sh
./tarspatch/util/init.sh
cd -

##安装nodejs环境
wget -qO- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash
source ~/.bashrc
#nvm install v8.11.3
#nvm install v7.10.1
nvm install v6.14.4

##安装web管理系统
cd $PWD_DIR/
git submodule update --init --recursive web
cd web/
npm install -g pm2 --registry=https://registry.npm.taobao.org
#sed -i "s/registry.tars.com/${MachineIp}/g" `grep registry1.tars.com -rl ./config/*`
#sed -i "s/    192.168.2.131/${MachineIp}/g" `grep     192.168.2.131 -rl ./config/*`
npm install --registry=https://registry.npm.taobao.org
npm run prd

cd -

mkdir -p /data/log/tars/
