# OpenStack Install Script

## Environment
 * OS: Ubuntu 15.10 Server (amd64) minimal
 * OpenStack: Liberty
 * _All-in-one_

## These scripts can install...
 * Keystone
 * Glance
 * Nova
 * Neutron
 * Ironic

## How to Use
Service password and Controller Node's IPaddr is written in each scripts.
Please change your environment.

### Install Keystone
 1. `chmod +x install-keystone.sh`
 2. `sudo ./install-keystone.sh` (Need root privilege)

### Install Glance
 1. `chmod +x install-glance.sh`
 2. `sudo ./install-glance.sh` (Need root privilege)

### Install Nova
 1. `chmod +x install-nova.sh`
 2. `sudo ./install-nova.sh` (Need root privilege)

### Install Neutron
 1. `chmod +x install-neutron.sh`
 2. `sudo ./install-neutron.sh` (Need root privilege)
 This script _DO NOT_ configure bridge interfaces of openvswitch.

## TODO
 * Ironic Install Script
 * check root privilege
