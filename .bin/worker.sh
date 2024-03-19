#!/bin/sh

cd /app || exit
gosu django python ./manage.py qcluster
