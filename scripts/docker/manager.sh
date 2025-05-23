#!/usr/bin/env bash
# desc: Initialize Docker Swarm manager and create overlay network
set -e

IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}')

if [[ -z "$IP" ]]; then
  echo "Error: Could not determine IP address"
  exit 1
fi

echo "Initializing Docker Swarm manager on $IP..."

docker swarm init --advertise-addr "$IP"
echo "Creating caddy_net overlay network..."
docker network create --driver overlay --attachable caddy_net

echo
echo "=== Swarm Manager Setup Complete ==="
echo "Manager IP: $IP"
echo
echo "To join workers to this swarm, run on worker nodes:"
docker swarm join-token worker

echo
echo "To join managers to this swarm, run on manager nodes:"
docker swarm join-token manager
