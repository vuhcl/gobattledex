#!/bin/sh

cd /app || exit
# /tailscale.sh
gosu django python /app/manage.py qcluster
