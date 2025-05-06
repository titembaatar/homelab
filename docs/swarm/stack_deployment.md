# Docker Stack Deployment for Swarm
How to deploy Docker Compose files (stack files) specifically for Docker Swarm, including overlay networks and secrets management.

## Docker Compose vs. Docker Stack
While both use the same YAML syntax, there are important differences between Docker Compose for standalone containers and Docker Stack for Swarm:
| Feature | Docker Compose | Docker Stack (Swarm) |
|---------|---------------|----------------------|
| Command | `docker-compose up` | `docker stack deploy` |
| File version | Supports v2.x and v3.x | Requires v3.x |
| Networks | Basic bridge networks | Overlay networks across nodes |
| Volumes | Local volumes | Can use NFS or other distributed storage |
| Environment variables | Supported | Supported |
| Environment file | Supported | Not Supported |
| Secrets | Limited support | Native secrets management |
| Deployment config | Not applicable | Replicas, update policy, placement constraints |
| Scaling | Manual scaling | Automated scaling and orchestration |
| Commands in YAML | Supports `command` | Supports `command` |
| Build from Dockerfile | Supports `build` | **Does not support** `build` (pre-built images in `Dockerfile/`) |

## Creating Overlay Networks
Before deploying stacks, create overlay networks that services can use to communicate across nodes:
```bash
# Create a network for ingress services
docker network create --driver overlay --attachable caddy_net
```

List all networks to verify creation:
```bash
docker network ls --filter driver=overlay
```

## Managing Docker Secrets
Create secrets to securely handle sensitive information:
```bash
# Method 1: Create a secret from standard input
echo "my-secret" | docker secret create secret-name -

# Method 2: Create a secret from a file
docker secret create secret-name /path/to/my-secret

# Method 3: Use `scripts/swarm/create-secret.sh`
./create-secret.sh secret-name "my-secret"
```

List all created secrets:
```bash
docker secret ls
```

## Creating a Stack File
Create a `docker-compose.yml` file with Swarm-specific configurations:
```yaml
services:
  container:
    image: image
    volumes:
      - volume:/data
    secrets:
      - my-secret
    networks:
      - external
      - stack
    deploy:
      labels:
        caddy: http://service.example.com
        caddy.reverse_proxy: "{{upstreams <port>}}"
        caddy.import: tinyauth_forwarder *
      # placement:
      #   constraints:
      #     - node.role == manager

volumes:
  volume:
    driver: local
    driver_opts:
      type: nfs
      o: addr=10.0.0.10,rw,defaults,soft,_netdev,noatime,nodiratime
      device: ":/path/to/nfs-share"

networks:
  external:
    external: true
  stack:
    driver: overlay

secrets:
  my-secret:
    external: true
```

## Deploying a Stack
Deploy a stack from your compose file:
```bash
cd /mnt/yesui/stacks/my-stack

# Deploy the stack
docker stack deploy -c docker-compose.yml my-stack-name
```

## Managing Stacks
Common stack management commands:
```bash
# List all stacks
docker stack ls

# List tasks (containers) in a stack
docker stack ps my-stack-name

# List services in a stack
docker stack services my-stack-name

# View logs for a service
docker service logs my-stack-name_service-name

# Update a stack (after changing docker-compose.yml)
docker stack deploy -c docker-compose.yml my-stack-name

# Remove a stack
docker stack rm my-stack-name
```
