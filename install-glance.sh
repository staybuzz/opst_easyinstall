#/bin/bash

# Environment
. ./env.conf
. $HOME/keystonerc_admin

create_db(){
	# Configure MySQL for Glance
	MYSQL="mysql -uroot -p$PASSWORD -e"
	$MYSQL "CREATE DATABASE glance;"
	$MYSQL "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$PASSWORD';"
	$MYSQL "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%'  IDENTIFIED BY '$PASSWORD';"
}

create_entity(){
	# create user
	openstack user create --password $PASSWORD glance
	
	# Add the admin role to the glance user and service project
	openstack role add --project service --user glance admin
	
	# Create the glance service entity
	openstack service create --name glance --description "OpenStack Image service" image
	
	# Create the Image service API endpoint
	openstack endpoint create \
  --publicurl http://$CONTROLLER:9292 \
  --internalurl http://$CONTROLLER:9292 \
  --adminurl http://$CONTROLLER:9292 \
  --region RegionOne \
  image
}

install_packages(){
	apt install -y glance python-glanceclient
}

config_setting(){
	echo $1
	sed -i "/^\[database\]/a connection = mysql:\/\/glance:$PASSWORD@$CONTROLLER\/glance" $1
	sed -i "s/^\[keystone_authtoken\]/#\[keystone_authtoken\]/" $1
	cat <<EOF >> $1
[keystone_authtoken]
auth_uri = http://$CONTROLLER:5000
auth_url = http://$CONTROLLER:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = glance
password = $PASSWORD
EOF
	sed -i "/^\[paste_deploy\]/a flavor = keystone" $1
	
	if [ $1 = "/etc/glance/glance-api.conf" ]; then
		sed -i "s/^\[glance_store\]/#\[glance_store\]/" $1
		cat <<EOF >> $1
[glance_store]
default_store = file
filesystem_store_datadir = /var/lib/glance/images/
EOF
	fi

	sed -i "/^\[DEFAULT\]/a enable_v3_api = true" $1
	sed -i "/^\[DEFAULT\]/a notification_driver = noop" $1
	sed -i "/^\[DEFAULT\]/a verbose = true" $1
	sed -i "/^\[DEFAULT\]/a debug = true" $1
}

sync_db(){
	su -s /bin/sh -c "glance-manage db_sync" glance
}

service_restart(){
	service glance-registry restart
	service glance-api restart
}

create_db
create_entity
install_packages
config_setting /etc/glance/glance-api.conf
config_setting /etc/glance/glance-registry.conf
sync_db
service_restart
