#/bin/sh

# Environment
PASSWORD=password
CONTROLLER=192.168.0.30

create_db(){
	# Configure MySQL for Cinder
	MYSQL="mysql -uroot -ppassword -e"
	$MYSQL "CREATE DATABASE cinder;"
	$MYSQL "GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$PASSWORD';"
	$MYSQL "GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%'  IDENTIFIED BY '$PASSWORD';"
}

create_entity(){
	# create user
	openstack user create --password $PASSWORD cinder
	
	# Add the admin role to the cinder user and service project
	openstack role add --project service --user cinder admin
	
	# Create the cinder service entity
	openstack service create --name cinder --description "OpenStack Block Storage" volume
	openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
	
	# Create the Volume service API endpoint
	openstack endpoint create \
  	--publicurl http://$CONTROLLER:8776/v2/%\(tenant_id\)s \
	--internalurl http://$CONTROLLER:8776/v2/%\(tenant_id\)s \
	--adminurl http://$CONTROLLER:8776/v2/%\(tenant_id\)s \
	--region RegionOne \
  	volume

	openstack endpoint create \
  	--publicurl http://$CONTROLLER:8776/v2/%\(tenant_id\)s \
	--internalurl http://$CONTROLLER:8776/v2/%\(tenant_id\)s \
	--adminurl http://$CONTROLLER:8776/v2/%\(tenant_id\)s \
	--region RegionOne \
  	volumev2
}

install_packages(){
	apt install -y cinder-volume cinder-api cinder-scheduler python-cinderclient python-mysqldb
}

config_setting(){
	echo $1
	sed -i "/^\[DEFAULT\]/a glance_host = $CONTROLLER" $1
	sed -i "/^\[DEFAULT\]/a enabled_backends = lvm" $1
	sed -i "/^\[DEFAULT\]/a my_ip = $CONTROLLER" $1
	sed -i "/^\[DEFAULT\]/a rpc_backend = rabbit" $1
	sed -i "/^\[DEFAULT\]/a enable_v3_api = true" $1
	sed -i "/^\[DEFAULT\]/a debug = true" $1


	cat << EOF >> $1
[oslo_messaging_rabbit]
rabbit_host = $CONTROLLER
rabbit_userid = openstack
rabbit_password = $PASSWORD
  
[database]
connection = mysql://cinder:$PASSWORD@$CONTROLLER/cinder

[keystone_authtoken]
auth_uri = http://$CONTROLLER:5000
auth_url = http://$CONTROLLER:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = cinder
password = $PASSWORD

[lvm]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
iscsi_protocol = iscsi
iscsi_helper = tgtadm

[oslo_concurrency]
lock_path = /var/lock/cinder
EOF
}

sync_db(){
	su -s /bin/sh -c "cinder-manage db sync" cinder
}

service_restart(){
	service cinder-scheduler restart
	service cinder-api restart
	service tgt restart
	service cinder-volume restart
}

create_db
create_entity
install_packages
config_setting /etc/cinder/cinder.conf
sync_db
service_restart
