#!/usr/bin/env bash
set -e

WORKER_TOKEN=$1
MANAGER_IP=$2

if [ "$WORKER_TOKEN" = "" ] || [ "$MANAGER_IP" = "" ]; then
  echo "Usage :"
  echo "  servarr.sh <worker-token> <manager-ip>"
  echo "Exiting..."
  exit 0
fi

"$HOME"/homelab/scripts/docker/worker.sh "$WORKER_TOKEN" "$MANAGER_IP"

docker network create servarr_net
docker compose -f "$HOME"/homelab/docker/servarr/docker-compose.yaml up -d
