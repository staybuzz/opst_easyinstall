#/bin/sh
# Install Neutron(include networking)

# Environment
PASSWORD=password
CONTROLLER=192.168.0.30

set_network_parameter(){
  cat <<EOF >> /etc/sysctl.conf
net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
EOF

  sysctl -p
}

create_db(){
# Configure MySQL for Neutron
  MYSQL="mysql -uroot -ppassword -e"
  $MYSQL "CREATE DATABASE neutron;"
  $MYSQL "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$PASSWORD';"
  $MYSQL "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%'  IDENTIFIED BY '$PASSWORD';"
}

create_entity(){
# create user
  openstack user create --password $PASSWORD neutron

# Add the admin role to the neutron user and service project
  openstack role add --project service --user neutron admin

# Create the neutron service entity
  openstack service create --name neutron \
  --description "OpenStack Networking" network

# Create the Image service API endpoint
    openstack endpoint create \
      --publicurl http://$CONTROLLER:9696 \
      --adminurl http://$CONTROLLER:9696 \
      --internalurl http://$CONTROLLER:9696 \
      --region RegionOne \
      network
}

install_packages(){
  apt install -y neutron-server neutron-plugin-ml2 python-neutronclient neutron-plugin-ml2 neutron-plugin-openvswitch-agent neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent
}

config_setting_neutron(){
  # database
  sed -i "/connection = sqlite:\/\/\/\/var\/lib\/neutron\/neutron\.sqlite/connection = mysql:\/\/neutron:$PASSWORD@$CONTROLLER\/neutron/" /etc/neutron/neutron.conf
  
  sed -i "/^\[DEFAULT\]/a rpc_backend = rabbit" /etc/neutron/neutron.conf
  sed -i "/^\[DEFAULT\]/a auth_strategy = keystone" /etc/neutron/neutron.conf
  sed -i "/^\[DEFAULT\]/a service_plugins = router" /etc/neutron/neutron.conf
  sed -i "/^\[DEFAULT\]/a allow_overlapping_ips = True" /etc/neutron/neutron.conf
  sed -i "/^\[DEFAULT\]/a notify_nova_on_port_status_changes = True" /etc/neutron/neutron.conf
  sed -i "/^\[DEFAULT\]/a notify_nova_on_port_data_changes = True" /etc/neutron/neutron.conf
  sed -i "/^\[DEFAULT\]/a nova_url = http://$CONTROLLER:8774/v2" /etc/neutron/neutron.conf
  sed -i "/^\[DEFAULT\]/a verbose = True" /etc/neutron/neutron.conf
  sed -i "/^\[DEFAULT\]/a debug = True" /etc/neutron/neutron.conf

  sed -i "/^\[oslo_messaging_rabbit\]/a rabbit_password = $PASSWORD" /etc/neutron/neutron.conf
  sed -i "/^\[oslo_messaging_rabbit\]/a rabbit_userid = openstack" /etc/neutron/neutron.conf
  sed -i "/^\[oslo_messaging_rabbit\]/a rabbit_host = $CONTROLLER" /etc/neutron/neutron.conf
  
  # keystone_authtoken
  sed -i "/^auth_uri = http:\/\/127\.0\.0\.1:35357\/v2\.0\//auth_uri = http:\/\/$CONTROLLER:35357\/v2\.0\//" /etc/neutron/neutron.conf
  sed -i "/^identity_uri = http:\/\/127\.0\.0\.1:5000/identity_uri = http:\/\/$CONTROLLER:5000/" /etc/neutron/neutron.conf
  sed -i "/^admin_tenant_name = %SERVICE_TENANT_NAME%/admin_tenant_name = admin_tenant_name = service/" /etc/neutron/neutron.conf
  sed -i "/^admin_user = %SERVICE_USER%/admin_user = neutron/" /etc/neutron/neutron.conf
  sed -i "/^admin_password = %SERVICE_PASSWORD%/admin_password = $PASSWORD/" /etc/neutron/neutron.conf
  
  sed -i "s/^\[nova\]/#\[nova\]/" /etc/neutron/neutron.conf
  cat <<EOF >> /etc/neutron/neutron.conf
[nova]
auth_url = http://$CONTROLLER:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
region_name = RegionOne
project_name = service
username = nova
password = $PASSWORD
EOF
}

config_setting_ml2(){
  sed -i "/^\[ml2\]/a mechanism_drivers = openvswitch" /etc/neutron/plugins/ml2/ml2_conf.ini
  sed -i "/^\[ml2\]/a tenant_network_types = gre" /etc/neutron/plugins/ml2/ml2_conf.ini
  sed -i "/^\[ml2\]/a type_drivers = flat,vlan,gre,vxlan" /etc/neutron/plugins/ml2/ml2_conf.ini
  
  sed -i "/^\[ml2_type_gre\]/a tunnel_id_ranges = 1:1000" /etc/neutron/plugins/ml2/ml2_conf.ini
  
  sed -i "/^\[ml2_type_flat\]/a flat_networks = external" /etc/neutron/plugins/ml2/ml2_conf.ini
  
  sed -i "/^\[securitygroup\]/a firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver" /etc/neutron/plugins/ml2/ml2_conf.ini
  sed -i "/^\[securitygroup\]/a enable_ipset = True" /etc/neutron/plugins/ml2/ml2_conf.ini
  sed -i "/^\[securitygroup\]/a enable_security_group = True" /etc/neutron/plugins/ml2/ml2_conf.ini
}

config_setting_ovs(){
  sed -i "/^\[ovs\]/a bridge_mappings = external:br-ex" /etc/neutron/plugins/ml2/openvswitch_agent.ini
  sed -i "/^\[ovs\]/a local_ip = $CONTROLLER" /etc/neutron/plugins/ml2/openvswitch_agent.ini
  
  sed -i "/^\[agent\]/a tunnel_types = gre" /etc/neutron/plugins/ml2/openvswitch_agent.ini
}

config_setting_l3(){
  sed -i "/^\[DEFAULT\]/a router_delete_namespaces = True" /etc/neutron/l3_agent.ini
  sed -i "/^\[DEFAULT\]/a external_network_bridge =" /etc/neutron/l3_agent.ini
  sed -i "/^\[DEFAULT\]/a neutron.agent.linux.interface.OVSInterfaceDriver" /etc/neutron/l3_agent.ini
  sed -i "/^\[DEFAULT\]/a verbose = True" /etc/neutron/l3_agent.ini
  sed -i "/^\[DEFAULT\]/a debug = True" /etc/neutron/l3_agent.ini
}

config_setting_dhcp(){
  sed -i "/^\[DEFAULT\]/a dhcp_delete_namespaces = True" /etc/neutron/dhcp_agent.ini
  sed -i "/^\[DEFAULT\]/a dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq" /etc/neutron/dhcp_agent.ini
  sed -i "/^\[DEFAULT\]/a neutron.agent.linux.interface.OVSInterfaceDriver" /etc/neutron/dhcp_agent.ini
  sed -i "/^\[DEFAULT\]/a verbose = True" /etc/neutron/dhcp_agent.ini
  sed -i "/^\[DEFAULT\]/a debug = True" /etc/neutron/dhcp_agent.ini
}

config_setting_metadata(){
  sed -i "s/auth_url = http:\/\/localhost:5000\/v2.0/auth_url = http:\/\/$CONTROLLER:5000\/v2.0/" /etc/neutron/metadata_agent.ini
  sed -i "/^admin_tenant_name = %SERVICE_TENANT_NAME%/admin_tenant_name = admin_tenant_name = service/" /etc/neutron/metadata_agent.ini
  sed -i "admin_user = %SERVICE_USER%/admin_user = neutron/" /etc/neutron/metadata_agent.ini
  sed -i "admin_password = %SERVICE_PASSWORD%/admin_password = $PASSWORD/" /etc/neutron/metadata_agent.ini
  
  sed -i "/^\[DEFAULT\]/a nova_metadata_ip = $CONTROLLER" /etc/neutron/metadata_agent.ini
  sed -i "/^\[DEFAULT\]/a metadata_proxy_shared_secret = $PASSWORD" /etc/neutron/metadata_agent.ini
  sed -i "/^\[DEFAULT\]/a " /etc/neutron/metadata_agent.ini
  sed -i "/^\[DEFAULT\]/a " /etc/neutron/metadata_agent.ini
  
  sed -i "/^\[DEFAULT\]/a verbose = True" /etc/neutron/metadata_agent.ini
  sed -i "/^\[DEFAULT\]/a debug = True" /etc/neutron/metadata_agent.ini
}

config_setting_nova(){
  sed -i "/^\[DEFAULT\]/a metadata_proxy_shared_secret = $PASSWORD \n" /etc/nova/nova.conf
  sed -i "/^\[DEFAULT\]/a service_metadata_proxy = True" /etc/nova/nova.conf
  sed -i "/^\[DEFAULT\]/a firewall_driver = nova.virt.firewall.NoopFirewallDriver\n" /etc/nova/nova.conf
  sed -i "/^\[DEFAULT\]/a linuxnet_interface_driver = nova.network.linux_net.LinuxOVSInterfaceDriver" /etc/nova/nova.conf
  sed -i "/^\[DEFAULT\]/a security_group_api = neutron" /etc/nova/nova.conf
  sed -i "/^\[DEFAULT\]/a network_api_class = nova.network.neutronv2.api.API" /etc/nova/nova.conf

  cat <<EOF >> /etc/nova/nova.conf
[neutron]
url = http://$CONTROLLER:9696
auth_strategy = keystone
admin_auth_url = http://$CONTROLLER:35357/v2.0
admin_tenant_name = service
admin_username = neutron
admin_password = $PASSWORD
EOF
}

sync_db(){
  su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
}

service_restart(){
  for i in nova-api neutron-server openvswitch-switch neutron-plugin-openvswitch-agent neutron-l3-agent neutron-l3-agent neutron-metadata-agent ; do
    systemctl restart $i
  done
}

set_network_parameter
create_db
create_entity
install_packages
config_setting_neutron
config_setting_ml2
config_setting_ovs
config_setting_l3
config_setting_dhcp
config_setting_metadata
config_setting_nova
sync_db
service_restart