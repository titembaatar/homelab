#!/usr/bin/env bash
set -e

$HOME/homelab/scripts/docker/debian-install.sh
$HOME/homelab/scripts/docker/manager.sh

docker network create gateway_net
docker compose -f $HOME/homelab/docker/caddy/docker-compose.yaml up -d
docker compose -f $HOME/homelab/docker/gateway/docker-compose.yaml up -d
