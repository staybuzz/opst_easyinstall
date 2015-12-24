#/bin/bash
# Install Horizon

# Environment
. ./env.conf

install_packages(){
  apt install -y openstack-dashboard
}

config_setting(){
  sed -i "s/^OPENSTACK_HOST = \"127.0.0.1\"$/OPENSTACK_HOST = \"$CONTROLLER\"/" /etc/openstack-dashboard/local_settings.py
  sed -i "s/^OPENSTACK_KEYSTONE_DEFAULT_ROLE = \"_member_\"/OPENSTACK_KEYSTONE_DEFAULT_ROLE = \"user\"/" /etc/openstack-dashboard/local_settings.py
  sed -i "s/^DEBUG = False/DEBUG = True" /etc/openstack-dashboard/local_settings.py
}

service_restart(){
  service apache2 reload
}

install_packages
config_setting
service_restart
