#!/bin/bash
# Install Nova(include nova-compute)

# Environment
. ../env.conf
. $HOME/keystonerc_admin

install_packages(){
  apt install -y nova-compute sysfsutils
}

config_setting(){
  sed -i "/^\[DEFAULT\]/a firewall_driver = nova.virt.firewall.NoopFirewallDriver" /etc/nova/nova.conf
  sed -i "/^\[DEFAULT\]/a linuxnet_interface_driver = nova.network.linux_net.NeutronLinuxBridgeInterfaceDriver" /etc/nova/nova.conf
  sed -i "/^\[DEFAULT\]/a security_group_api = neutron" /etc/nova/nova.conf
  sed -i "/^\[DEFAULT\]/a network_api_class = nova.network.neutronv2.api.API" /etc/nova/nova.conf
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

[neutron]
url = http://$CONTROLLER:9696
auth_strategy = keystone
admin_auth_url = http://$CONTROLLER:35357/v2.0
admin_tenant_name = service
admin_username = neutron
admin_password = $PASSWORD

[vnc]
enabled = True
vncserver_listen = $CONTROLLER
vncserver_proxyclient_address = $CONTROLLER
novncproxy_base_url = http://$COMPUTE:6080/vnc_auto.html
#vnc_keymap=ja
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
