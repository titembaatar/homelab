#!/usr/bin/env bash
# desc: Initialize Docker Swarm manager and create overlay network
set -e

ip=$(ip route get 1.1.1.1 | awk '{print $7; exit}')

if [[ -z "$ip" ]]; then
  echo "Error: Could not determine IP address"
  exit 1
fi

echo "Initializing Docker Swarm manager on $ip..."

docker swarm init --advertise-addr "$ip"
echo "Creating caddy_net overlay network..."
docker network create --driver overlay --attachable caddy_net

echo
echo "=== Swarm Manager Setup Complete ==="
echo "Manager IP: $ip"
echo
echo "To join workers to this swarm, run on worker nodes:"
docker swarm join-token worker

echo
echo "To join managers to this swarm, run on manager nodes:"
docker swarm join-token manager
