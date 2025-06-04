#!/usr/bin/env bash
set -e

worker_token=$1
manager_ip=$2

if [ "$worker_token" = "" ] || [ "$manager_ip" = "" ]; then
  echo "Usage :"
  echo "  ger.sh <worker-token> <manager-ip>"
  echo "Exiting..."
  exit 0
fi

$HOME/homelab/scripts/docker/worker.sh "$worker_token" "$manager_ip"

docker compose -f $HOME/homelab/docker/glance/docker-compose.yaml up -d
docker compose -f $HOME/homelab/docker/immich/docker-compose.yaml up -d
