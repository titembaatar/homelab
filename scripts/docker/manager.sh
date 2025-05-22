#!/usr/bin/env bash
set -e

"$HOME"/homelab/scripts/docker/debian-install.sh

IP=$(ip a | grep '10.0.0.' | awk '{print $2}' | cut -d '/' -f 1)

sudo docker swarm init --advertise-addr "$IP"
sudo docker network create --driver overlay --attachable caddy_net
sudo docker swarm join-token worker
echo
echo "Manager IP: '$IP'"
