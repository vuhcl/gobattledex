#!/bin/sh

cd /app || exit
# /tailscale.sh
python -m manage migrate --noinput
