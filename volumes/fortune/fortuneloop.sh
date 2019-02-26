#!/bin/bash
trap "exit" SIGINT
while :
do
  echo $(date) Writing forture to /var/htdocs/index.html
  /usr/games/fortune > /var/htdocs/index.html
  sleep 10
done
