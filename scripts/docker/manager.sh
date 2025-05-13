#!/usr/bin/env bash
set -e

IP=$(ip a | grep '10.0.0.' | awk '{print $2}' | cut -d '/' -f 1)

docker swarm init --advertise-addr "$IP"
docker network create --driver overlay --attachable caddy_net
docker swarm join-token worker
echo
echo "Manager IP: '$IP'"
