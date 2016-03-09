#!/bin/bash

apt install -y ubuntu-cloud-keyring curl software-properties-common
add-apt-repository cloud-archive:liberty
apt-get update && apt-get -y dist-upgrade
