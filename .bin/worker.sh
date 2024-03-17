#!/bin/sh

cd /app || exit
gosu django python /app/manage.py qcluster
