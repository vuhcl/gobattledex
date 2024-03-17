#!/bin/sh

cd /app || exit
python -m manage migrate --noinput
