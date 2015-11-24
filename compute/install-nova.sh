#!/bin/sh
# Install Nova(include nova-compute)

# Environment
PASSWORD=password
CONTROLLER=192.168.0.30
COMPUTE=192.168.0.31

install_packages(){
  apt install -y nova-compute sysfsutils
}

config_setting(){
  sed -i "/^\[DEFAULT\]/a novncproxy_base_url = http://$CONTROLLER:6080/vnc_auto.html" /etc/nova/nova.conf
  sed -i "/^\[DEFAULT\]/a vncserver_proxyclient_address = $COMPUTE" /etc/nova/nova.conf
  sed -i "/^\[DEFAULT\]/a vncserver_listen = 0.0.0.0" /etc/nova/nova.conf
  sed -i "/^\[DEFAULT\]/a vnc_enabled = True" /etc/nova/nova.conf
  sed -i "/^\[DEFAULT\]/a my_ip = $COMPUTE" /etc/nova/nova.conf
  sed -i "/^\[DEFAULT\]/a auth_strategy = keystone" /etc/nova/nova.conf
  sed -i "/^\[DEFAULT\]/a rpc_backend = rabbit" /etc/nova/nova.conf
  sed -i "/^\[DEFAULT\]/a verbose = true" /etc/nova/nova.conf
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
username = nova
password = $PASSWORD

[glance]
host = $CONTROLLER

[oslo_concurrency]
lock_path = /var/lib/nova/tmp
EOF
}

service_restart(){
  for i in nova-compute; do
    service $i restart 
  done
}

install_packages
config_setting
service_restart
