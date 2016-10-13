#!/usr/bin/env bash

export VOYAGER_IP=192.168.50.5:5672
sed -i -- "s/amqp:\/\/localhost/amqp:\/\/${VOYAGER_IP}/g" /opt/monorail/config.json
sed -i -- "s/\"authEnabled\": true,/\"authEnabled\": false,/g" /opt/monorail/config.json

set +e
DHCPSTART=$(sudo service isc-dhcp-server status | grep -o start)
echo "DHCPSTART = ${DHCPSTART}"
if [ -z $DHCPSTART ]; then
    echo "The DHCP server is not running. Attempting to restart it."
    sudo service isc-dhcp-server restart

    DHCPSTART=$(sudo service isc-dhcp-server status | grep -o start)

    if [ -z $DHCPSTART ]; then
      echo "Could not restart the DHCP server. Exiting now."
      exit 1
    fi
fi
set -e

sudo pm2 start rackhd-pm2-config.yml
