#/bin/bash
# Install Neutron(include networking)

# Environment
. ../env.conf

set_network_parameter(){
  cat <<EOF >> /etc/sysctl.conf
net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
EOF

  sysctl -p
}

install_packages(){
  apt install -y neutron-plugin-linuxbridge-agent conntrack
}

config_setting_neutron(){
  # database
  sed -i "s/connection = sqlite:\/\/\/\/var\/lib\/neutron\/neutron\.sqlite/connection = mysql:\/\/neutron:$PASSWORD@$CONTROLLER\/neutron/" /etc/neutron/neutron.conf
  
  sed -i "/^\[DEFAULT\]/a allow_overlapping_ips = True" /etc/neutron/neutron.conf
  sed -i "/^\[DEFAULT\]/a core_plugin = ml2" /etc/neutron/neutron.conf

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
  sed -i "s/^auth_uri = http:\/\/127\.0\.0\.1:35357\/v2\.0\//auth_uri = http:\/\/$CONTROLLER:35357\/v2\.0\//" /etc/neutron/neutron.conf
  sed -i "s/^identity_uri = http:\/\/127\.0\.0\.1:5000/identity_uri = http:\/\/$CONTROLLER:5000/" /etc/neutron/neutron.conf
  sed -i "s/^admin_tenant_name = %SERVICE_TENANT_NAME%/admin_tenant_name = service/" /etc/neutron/neutron.conf
  sed -i "s/^admin_user = %SERVICE_USER%/admin_user = neutron/" /etc/neutron/neutron.conf
  sed -i "s/^admin_password = %SERVICE_PASSWORD%/admin_password = $PASSWORD/" /etc/neutron/neutron.conf
  
}

config_setting_linuxbridge(){
  sed -i "/^\[linux_bridge\]/a physical_interface_mappings = external:eth0" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
  sed -i "/^\[vxlan\]/a l2_population = True" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
  sed -i "/^\[vxlan\]/a local_ip = $COMPUTE" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
  sed -i "/^\[vxlan\]/a enable_vxlan = True" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
  
  sed -i "/^\[agent\]/a prevent_arp_spoofing = True" /etc/neutron/plugins/ml2/linuxbridge_agent.ini

  sed -i "/^\[securitygroup\]/a firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
  sed -i "/^\[securitygroup\]/a enable_security_group = True" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
}

config_setting_nova(){
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

service_restart(){
  for i in nova-compute neutron-plugin-linuxbridge-agent; do
    service $i restart
  done
}

set_network_parameter
install_packages
config_setting_neutron
config_setting_linuxbridge
config_setting_nova
service_restart
