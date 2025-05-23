#!/usr/bin/env bash
# desc: Join Docker Swarm as worker node
set -e

WORKER_TOKEN="$1"
MANAGER_IP="$2"

if [[ -z "$WORKER_TOKEN" || -z "$MANAGER_IP" ]]; then
  echo "Usage: $0 <worker_token> <manager_ip>"
  exit 1
fi

echo "Joining Docker Swarm as worker..."

docker swarm join --token "$WORKER_TOKEN" "$MANAGER_IP:2377"

if ! docker network ls | grep -q caddy_net; then
  echo "Warning: caddy_net network not found"
  echo "This network should be created by the swarm manager"
fi

echo "Worker node successfully joined the swarm"
