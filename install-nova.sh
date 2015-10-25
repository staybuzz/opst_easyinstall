#!/bin/sh
# Install Nova(include nova-compute)

# Environment
PASSWORD=password
CONTROLLER=192.168.0.30

create_db(){
# Configure MySQL for Nova
  MYSQL="mysql -uroot -ppassword -e"
  $MYSQL "CREATE DATABASE nova;"
  $MYSQL "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$PASSWORD';"
  $MYSQL "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%'  IDENTIFIED BY '$PASSWORD';"
}

create_entity(){
# create user
  openstack user create --password $PASSWORD nova

# Add the admin role to the nova user and service project
  openstack role add --project service --user nova admin

# Create the nova service entity
  openstack service create --name nova --description "OpenStack Compute" compute
  
# Create the Compute service API endpoint
  openstack endpoint create \
	--publicurl http://$CONTROLLER:8774/v2/%\(tenant_id\)s \
	--internalurl http://$CONTROLLER:8774/v2/%\(tenant_id\)s \
	--adminurl http://$CONTROLLER:8774/v2/%\(tenant_id\)s \
	--region RegionOne \
	compute
}

install_packages(){
  apt install -y nova-api nova-cert nova-conductor nova-consoleauth nova-novncproxy nova-scheduler python-novaclient \ 
  nova-compute sysfsutils
}

config_setting(){
  sed -i "/^\[DEFAULT\]/a novncproxy_base_url = http://$CONTROLLER:6080/vnc_auto.html" /etc/nova/nova.conf
  sed -i "/^\[DEFAULT\]/a vncserver_proxyclient_address = $CONTROLLER" /etc/nova/nova.conf
  sed -i "/^\[DEFAULT\]/a vncserver_listen = $CONTROLLER" /etc/nova/nova.conf
  sed -i "/^\[DEFAULT\]/a vnc_enabled = True" /etc/nova/nova.conf
  sed -i "/^\[DEFAULT\]/a my_ip = $CONTROLLER" /etc/nova/nova.conf
  sed -i "/^\[DEFAULT\]/a auth_strategy = keystone" /etc/nova/nova.conf
  sed -i "/^\[DEFAULT\]/a rpc_backend = rabbit" /etc/nova/nova.conf
  sed -i "/^\[DEFAULT\]/a debug = true" /etc/nova/nova.conf
  
cat << EOF >> /etc/nova/nova.conf
[oslo_messaging_rabbit]
rabbit_host = $CONTROLLER
rabbit_userid = openstack
rabbit_password = $PASSWORD
  
[database]
connection = mysql://nova:$PASSWORD@$CONTROLLER/nova

[keystone_authtoken]
auth_uri = http://$CONTROLLER:5000
auth_url = http://$CONTROLLER:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = glance
password = $PASSWORD

[glance]
host = $CONTROLLER

[oslo_concurrency]
lock_path = /var/lib/nova/tmp
EOF
}

sync_db(){
  su -s /bin/sh -c "nova-manage db sync" nova
}

service_restart(){
  for i in nova-api nova-cert nova-consoleauth nova-scheduler nova-conductor nova-novncproxy nova-compute; do
    systemctl restart $i
  done
}

create_db
create_entity
install_packages
config_setting
sync_db
service_restart
