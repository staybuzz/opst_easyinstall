#!/bin/bash
# 2015.10.24
# Install Keystone

# Environment
. ./env.conf

create_db(){
	# Configure MySQL for Keystone
	MYSQL="mysql -uroot -ppassword -e"
	$MYSQL "CREATE DATABASE keystone;"
	$MYSQL "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$PASSWORD';"
	$MYSQL "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%'  IDENTIFIED BY '$PASSWORD';"
}

install_packages(){
	# Disable the keystone service from starting automatically after installation
	echo "manual" > /etc/init/keystone.override

	# Install Package
	apt install -y keystone python-openstackclient apache2 libapache2-mod-wsgi memcached python-memcache
}

config_setting(){
	# Configure Keystone
	RANDHEX=`openssl rand -hex 10`
	sed -i "s/#admin_token = ADMIN/admin_token = $RANDHEX/" /etc/keystone/keystone.conf
	sed -i "s/connection = sqlite:\/\/\/\/var\/lib\/keystone\/keystone.db/connection = mysql:\/\/keystone:$PASSWORD@$CONTROLLER\/keystone/" /etc/keystone/keystone.conf
	sed -i "s/#\(servers = localhost:11211\)/\1/" /etc/keystone/keystone.conf
	sed -i "s/#provider = uuid/provider = keystone.token.providers.uuid.Provider/" /etc/keystone/keystone.conf
	sed -i "/^\[token\]/a driver = keystone.token.persistence.backends.memcache.Token" /etc/keystone/keystone.conf
	sed -i "/^\[revoke\]/a driver = keystone.contrib.revoke.backends.sql.Revoke" /etc/keystone/keystone.conf
	sed -i "/^\[DEFAULT\]/a verbose = true" /etc/keystone/keystone.conf
	sed -i "/^\[DEFAULT\]/a debug = true" /etc/keystone/keystone.conf

	# Populate the Identity service database
	su -s /bin/sh -c "keystone-manage db_sync" keystone

	# Configure Apache HTTP server
	cat <<EOF > /etc/apache2/sites-available/wsgi-keystone.conf
Listen 5000
Listen 35357

<VirtualHost *:5000>
	WSGIDaemonProcess keystone-public processes=5 threads=1 user=keystone display-name=%{GROUP}
	WSGIProcessGroup keystone-public
	WSGIScriptAlias / /var/www/cgi-bin/keystone/main
	WSGIApplicationGroup %{GLOBAL}
	WSGIPassAuthorization On
	<IfVersion >= 2.4>
	  ErrorLogFormat "%{cu}t %M"
	</IfVersion>
	LogLevel info
	ErrorLog /var/log/apache2/keystone-error.log
	CustomLog /var/log/apache2/keystone-access.log combined
</VirtualHost>

<VirtualHost *:35357>
	WSGIDaemonProcess keystone-admin processes=5 threads=1 user=keystone display-name=%{GROUP}
	WSGIProcessGroup keystone-admin
	WSGIScriptAlias / /var/www/cgi-bin/keystone/admin
	WSGIApplicationGroup %{GLOBAL}
	WSGIPassAuthorization On
	<IfVersion >= 2.4>
	  ErrorLogFormat "%{cu}t %M"
	</IfVersion>
	LogLevel info
	ErrorLog /var/log/apache2/keystone-error.log
	CustomLog /var/log/apache2/keystone-access.log combined
</VirtualHost>
EOF

	# Enable the Identity service virtual hosts
	ln -s /etc/apache2/sites-available/wsgi-keystone.conf /etc/apache2/sites-enabled

	# Create the directory structure for the WSGI components
	mkdir -p /var/www/cgi-bin/keystone

	# Copy the WSGI components from the upstream repository into this directory
	curl http://git.openstack.org/cgit/openstack/keystone/plain/httpd/keystone.py?h=stable/liberty \
	| tee /var/www/cgi-bin/keystone/main /var/www/cgi-bin/keystone/admin

	# Adjust ownership and permissions on this directory and the files in it
	chown -R keystone:keystone /var/www/cgi-bin/keystone
	chmod 755 /var/www/cgi-bin/keystone/*

	# Restart Apache HTTP Server
	service apache2 restart

	# Remove Keystone SQLite DB
	rm -f /var/lib/keystone/keystone.db
	
	create_entity
}

create_entity(){
	# Authentication token
	export OS_TOKEN=$RANDHEX
	# Endpoint
	export OS_URL=http://$CONTROLLER:35357/v2.0
	
	# Create the service entity for the Identity service
	openstack service create --name keystone --description "OpenStack Identity" identity
	
	# Create the Identity service API endpoint
	openstack endpoint create \
  --publicurl http://$CONTROLLER:5000/v2.0 \
  --internalurl http://$CONTROLLER:5000/v2.0 \
  --adminurl http://$CONTROLLER:35357/v2.0 \
  --region RegionOne \
  identity
  
	# Create admin project
	openstack project create --description "Admin Project" admin
	
	# Create admin user
	openstack user create --password $PASSWORD admin
	
	# Create the admin role
	openstack role create admin
	
	# Add the admin role to the admin project and user
	openstack role add --project admin --user admin admin
	
	# Service and Demo Project
	openstack project create --description "Service Project" service
	openstack project create --description "Demo Project" demo
	openstack user create --password $PASSWORD demo
	openstack role create user
	openstack role add --project demo --user demo user
}

make_rc(){
	cat <<EOF > ~/keystonerc_admin
export OS_PROJECT_DOMAIN_ID=default
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_NAME=admin
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$PASSWORD
export OS_AUTH_URL=http://$CONTROLLER:35357
EOF
}

create_db
install_packages
config_setting
make_rc
