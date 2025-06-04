#!/usr/bin/env bash
# desc: Join Docker Swarm as worker node
set -e

worker_token="$1"
manager_ip="$2"

if [[ -z "$worker_token" || -z "$manager_ip" ]]; then
  echo "Usage: $0 <worker_token> <manager_ip>"
  exit 1
fi

echo "Joining Docker Swarm as worker..."

docker swarm join --token "$worker_token" "$manager_ip:2377"

if ! docker network ls | grep -q caddy_net; then
  echo "Warning: caddy_net network not found"
  echo "This network should be created by the swarm manager"
fi

echo "Worker node successfully joined the swarm"
