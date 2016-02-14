#/bin/bash
# Install Ironic

# Environment
. ./env.conf
. $HOME/keystonerc_admin

create_db(){
# Configure MySQL for Ironic
  MYSQL="mysql -uroot -p$PASSWORD -e"
  $MYSQL "CREATE DATABASE ironic;"
  $MYSQL "GRANT ALL PRIVILEGES ON ironic.* TO 'ironic'@'localhost' IDENTIFIED BY '$PASSWORD';"
  $MYSQL "GRANT ALL PRIVILEGES ON ironic.* TO 'ironic'@'%'  IDENTIFIED BY '$PASSWORD';"
}

create_entity(){
  # create user
  openstack user create --password $PASSWORD ironic
  
  # Add the admin role to the ironic user and service project
  openstack role add --project service --user ironic admin
  
  # Create the ironic service entity
  openstack service create --name ironic \
  --description "Ironic bare metal provisioning service" baremetal
  
  # Create the Baremetal service API endpoint
    openstack endpoint create \
      --publicurl http://$CONTROLLER:6385 \
      --adminurl http://$CONTROLLER:6385 \
      --internalurl http://$CONTROLLER:6385 \
      --region RegionOne \
      baremetal
}

install_packages(){
  apt install -y ironic-api ironic-conductor python-ironicclient ipmitool
}

config_setting(){
  sed -i "/^\[glance\]/a glance_host=$CONTROLLER" /etc/ironic/ironic.conf
  
  sed -i "/^\[neutron\]/a url=http://$CONTROLLER:9696" /etc/ironic/ironic.conf
  
  sed -i "/^\[keystone_authtoken\]/a auth_protocol=http" /etc/ironic/ironic.conf
  sed -i "/^\[keystone_authtoken\]/a admin_tenant_name=service" /etc/ironic/ironic.conf
  sed -i "/^\[keystone_authtoken\]/a admin_password=$PASSWORD" /etc/ironic/ironic.conf
  sed -i "/^\[keystone_authtoken\]/a admin_user=ironic" /etc/ironic/ironic.conf
  sed -i "/^\[keystone_authtoken\]/a auth_uri=http://$CONTROLLER:5000/" /etc/ironic/ironic.conf
  sed -i "/^\[keystone_authtoken\]/a auth_host=$CONTROLLER" /etc/ironic/ironic.conf
  
  sed -i "/^\[DEFAULT\]/a auth_strategy=keystone" /etc/ironic/ironic.conf
  sed -i "s/connection=sqlite:\/\/\/\/var\/lib\/ironic\/ironic\.db/connection = mysql:\/\/ironic:$PASSWORD@$CONTROLLER\/ironic/" /etc/ironic/ironic.conf
  
  sed -i "/^\[DEFAULT\]/a rabbit_password=$PASSWORD" /etc/ironic/ironic.conf
  sed -i "/^\[DEFAULT\]/a rabbit_userid=openstack" /etc/ironic/ironic.conf
  sed -i "/^\[DEFAULT\]/a rabbit_host=$CONTROLLER" /etc/ironic/ironic.conf
  sed -i "/^\[DEFAULT\]/a verbose = True" /etc/ironic/ironic.conf
  sed -i "/^\[DEFAULT\]/a debug = True" /etc/ironic/ironic.conf
}

sync_db(){
  su -s /bin/sh -c "ironic-dbsync --config-file /etc/ironic/ironic.conf create_schema" ironic
}

service_restart(){
  service ironic-api restart
  service ironic-conductor restart
}

create_db
create_entity
install_packages
config_setting
sync_db
service_restart
