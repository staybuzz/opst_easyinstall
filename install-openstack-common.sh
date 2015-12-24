#!/bin/sh

PASSWORD=password
CONTROLLER=192.168.0.30

apt install -y ubuntu-cloud-keyring
add-apt-repository cloud-archive:liberty
apt-get update && apt-get -y dist-upgrade

apt install -y mariadb-server python-mysqldb

sed -i "/^\[mysqld\]/a init-connect = 'SET NAMES utf8'" /etc/mysql/my.cnf
sed -i "/^\[mysqld\]/a innodb_file_per_table" /etc/mysql/my.cnf
sed -i "/^\[mysqld\]/a default-storage-engine = innodb" /etc/mysql/my.cnf
sed -i "s/bind-address[ \f\n\r\t]*=[ \f\n\r\t]*127.0.0.1/bind-address = $CONTROLLER/g" /etc/mysql/my.cnf

service mysql restart

apt install -y rabbitmq-server
rabbitmqctl add_user openstack $PASSWORD
rabbitmqctl set_permissions openstack ".*" ".*" ".*"
