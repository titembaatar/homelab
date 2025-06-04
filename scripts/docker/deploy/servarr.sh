#!/usr/bin/env bash
set -e

worker_token=$1
manager_ip=$2

if [ "$worker_token" = "" ] || [ "$manager_ip" = "" ]; then
  echo "Usage :"
  echo "  servarr.sh <worker-token> <manager-ip>"
  echo "Exiting..."
  exit 0
fi

$HOME/homelab/scripts/docker/worker.sh "$worker_token" "$manager_ip"

docker network create servarr_net
docker compose -f $HOME/homelab/docker/servarr/docker-compose.yaml up -d
