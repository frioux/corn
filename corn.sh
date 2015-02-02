#!/bin/dash

cd /opt/app

exec 2>&1 /sbin/setuser corn \
   carton exec \
   plackup -s Gazelle -E production
