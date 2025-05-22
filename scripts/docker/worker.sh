#!/usr/bin/env bash
set -e

WORKER_TOKEN=$1
MANAGER_IP=$2

"$HOME"/homelab/scripts/docker/debian-install.sh

sudo docker swarm join --token "$WORKER_TOKEN" "$MANAGER_IP":2377

CADDY_NET=$(docker network list | grep 'caddy_net')

if ! $CADDY_NET; then
  echo "No 'caddy_net' network."
  echo "Create 'caddy_net' network on swarm manager with:"
  echo "  docker network create --driver overlay --attachable caddy_net"
  echo "Exiting..."
  exit 0
fi
