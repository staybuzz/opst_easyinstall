# OpenStack Install Script
for PoC

## Environment
 * OS: Ubuntu 14.04 Server (amd64)
 * OpenStack: Liberty

## These scripts can install...
 * Keystone
 * Glance
 * Nova
 * Neutron

## How to Use
Service password and Controller Node's IPaddr is written in each scripts.
Please change your environment.

### Controller Node
#### Install Keystone
 1. `sudo ./install-keystone.sh` (Need root privilege)

#### Install Glance
 1. `sudo ./install-glance.sh` (Need root privilege)

#### Install Nova
 1. `sudo ./install-nova.sh` (Need root privilege)

#### Install Neutron
 1. `sudo ./install-neutron.sh` (Need root privilege)
 This script _DO NOT_ configure bridge interfaces of openvswitch.

### Compute Node

## TODO
 * check root privilege
 * env input prompt
 * horizon install script
 * mysql bind-address
