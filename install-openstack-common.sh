#!/bin/bash
. ./env.conf

apt install -y ubuntu-cloud-keyring
add-apt-repository -y cloud-archive:liberty
apt-get update

sudo debconf-set-selections <<< "mariadb-server mysql-server/root_password password $PASSWORD"
sudo debconf-set-selections <<< "mariadb-server mysql-server/root_password_again password $PASSWORD"
apt install -y mariadb-server python-mysqldb

sed -i "/^\[mysqld\]/a init-connect = 'SET NAMES utf8'" /etc/mysql/my.cnf
sed -i "/^\[mysqld\]/a innodb_file_per_table" /etc/mysql/my.cnf
sed -i "/^\[mysqld\]/a default-storage-engine = innodb" /etc/mysql/my.cnf
sed -i "s/bind-address[ \f\n\r\t]*=[ \f\n\r\t]*127.0.0.1/bind-address = $CONTROLLER/g" /etc/mysql/my.cnf

service mysql restart

apt install -y rabbitmq-server
rabbitmqctl add_user openstack $PASSWORD
rabbitmqctl set_permissions openstack ".*" ".*" ".*"
