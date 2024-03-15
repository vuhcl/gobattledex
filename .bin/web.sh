#!/bin/sh

cd /app || exit
# /tailscale.sh
gosu django python -m gunicorn pvpogo_tools.wsgi:application --config python:pvpogo_tools.gunicorn
