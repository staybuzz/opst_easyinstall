#!/bin/sh

PASSWORD=password

apt install -y ubuntu-cloud-keyring
apt-get update && apt-get -y dist-upgrade

apt install -y mariadb-server python-mysqldb

cat << EOF >> /etc/mysql/mariadb.conf.d/mysqld.cnf
default-storage-engine = innodb
innodb_file_per_table
init-connect = 'SET NAMES utf8'
EOF

systemctl restart mysql

apt install -y rabbitmq-server
rabbitmqctl add_user openstack $PASSWORD
rabbitmqctl set_permissions openstack ".*" ".*" ".*"