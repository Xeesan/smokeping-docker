#!/bin/bash

# Ensure permissions on dynamically mounted volumes are correct
chown -R smokeping:www-data /var/lib/smokeping

# Start Smokeping in the background
/usr/sbin/smokeping --config=/etc/smokeping/config --logfile=/var/log/smokeping.log

# Start Apache2 in the foreground to keep the container running
exec /usr/sbin/apache2ctl -D FOREGROUND
