if [ "$(whoami)" != "root" ];then
	echo "Please run this script as root"
	exit
fi
gdb -ex "thread apply all bt" -batch -p $(pidof mysqld) >> /home/mysql/mysql-gdb.txt
