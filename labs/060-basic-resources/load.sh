#!/bin/sh

while true; do
  curl -s localhost > /dev/null
  echo -n .;
  sleep 0.5
done