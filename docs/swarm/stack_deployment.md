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
| Secrets | Limited support | Native secrets management |
| Deployment config | Not applicable | Replicas, update policy, placement constraints |
| Scaling | Manual scaling | Automated scaling and orchestration |
| Commands in YAML | Supports `command` | Supports `command` |
| Build from Dockerfile | Supports `build` | **Does not support** `build` (use pre-built images only) |

## Creating Overlay Networks
Before deploying stacks, create overlay networks that services can use to communicate across nodes:
```bash
# Create a network for ingress services
docker network create --driver overlay --attachable caddy_net

# Create a network for media services
docker network create --driver overlay --attachable media_internal

# Create additional networks as needed for isolation
docker network create --driver overlay --attachable monitoring_net
docker network create --driver overlay --attachable database_net
```

List all networks to verify creation:

```bash
docker network ls --filter driver=overlay
```

## Managing Docker Secrets

Create secrets to securely handle sensitive information:

```bash
# Method 1: Create a secret from standard input
echo "your-cloudflare-api-token" | docker secret create cloudflare_api_token -

# Method 2: Create a secret from a file
docker secret create tunnel_token /path/to/tunnel_token_file

# Add more secrets as needed
docker secret create db_password /path/to/database_password_file
docker secret create tiny_auth_secret /path/to/tiny_auth_secret_file
```

List all created secrets:

```bash
docker secret ls
```

## Creating a Stack File

Create a `docker-compose.yml` file with Swarm-specific configurations:

```yaml
version: '3.8'  # Must be at least 3.x for Swarm

services:
  web:
    image: nginx:alpine  # Must use pre-built images, no 'build' directive
    deploy:  # Swarm-specific section
      replicas: 2
      update_config:
        parallelism: 1
        delay: 10s
        order: start-first
      restart_policy:
        condition: on-failure
        max_attempts: 3
      placement:
        constraints:
          - node.role == worker  # Run only on worker nodes
    ports:
      - "8080:80"
    networks:
      - frontend
    volumes:
      - web_content:/usr/share/nginx/html
    secrets:  # Mount secrets as files
      - source: web_cert
        target: /etc/ssl/cert.pem
        mode: 0400  # Read-only permission

  db:
    image: postgres:14
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.storage == true  # Run on nodes with 'storage' label
    environment:
      - POSTGRES_USER=user
      - POSTGRES_DB=mydb
      # Don't put passwords here; use secrets instead
    volumes:
      - db_data:/var/lib/postgresql/data
    networks:
      - backend
    secrets:
      - source: db_password
        target: /run/secrets/db_password
    command: postgres -c config_file=/etc/postgresql/postgresql.conf
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "user"]
      interval: 30s
      timeout: 5s
      retries: 3

networks:
  frontend:
    external: true  # Reference a pre-created overlay network
    name: caddy_net  # Name in 'docker network ls'
  backend:
    driver: overlay
    attachable: true  # Allow standalone containers to attach

volumes:
  web_content:
    driver: local
    driver_opts:
      type: nfs
      o: addr=10.0.0.10,nfsvers=4,rw,soft,noatime,nodiratime
      device: ":/flash/yesugen/web"
  db_data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=10.0.0.10,nfsvers=4,rw,soft,noatime,nodiratime
      device: ":/vault/khulan/postgres"

secrets:
  web_cert:
    external: true  # Reference a pre-created secret
  db_password:
    external: true  # Reference a pre-created secret
```

## Key Swarm-Specific Features

### 1. The `deploy` Section

This Swarm-only section controls how services are deployed:

```yaml
deploy:
  replicas: 3  # Number of container instances
  update_config:
    parallelism: 1  # Update one container at a time
    delay: 10s  # Wait 10s between updating containers
    failure_action: rollback  # What to do if update fails
    order: start-first  # Start new container before stopping old one
  restart_policy:
    condition: on-failure
    delay: 5s
    max_attempts: 3
  resources:
    limits:
      cpus: '0.5'
      memory: 50M
    reservations:
      cpus: '0.1'
      memory: 20M
  placement:
    constraints:
      - node.role == worker  # Only run on worker nodes
      - node.labels.region == eu  # Only run on nodes with specific labels
```

### 2. External Networks and Secrets

Reference pre-created networks and secrets:

```yaml
networks:
  frontend:
    external: true  # Use a pre-created network
    name: caddy_net  # The actual name from 'docker network ls'

secrets:
  api_token:
    external: true  # Use a pre-created secret
```

### 3. NFS Volumes for Persistence

Configure volumes to use NFS for distributed storage:

```yaml
volumes:
  config_data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=10.0.0.10,nfsvers=4,rw,soft,noatime,nodiratime
      device: ":/flash/yesugen/config"
```

## Deploying a Stack

Deploy a stack from your compose file:

```bash
# Change to the directory containing your docker-compose.yml
cd /mnt/yesui/stacks/my-stack

# Deploy the stack
docker stack deploy -c docker-compose.yml my-stack-name
```

## Managing Stacks

Common stack management commands:

```bash
# List all stacks
docker stack ls

# List services in a stack
docker stack services my-stack-name

# List tasks (containers) in a stack
docker stack ps my-stack-name

# View logs for a service
docker service logs my-stack-name_service-name

# Update a stack (after changing docker-compose.yml)
docker stack deploy -c docker-compose.yml my-stack-name

# Remove a stack
docker stack rm my-stack-name
```

## Example: Real-World Stack File

Here's an example of a more comprehensive stack for your homelab:

```yaml
version: '3.8'

services:
  # Reverse Proxy / TLS Termination
  caddy:
    image: caddy:2.7.4
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - caddy_data:/data
      - caddy_config:/config
      - /mnt/yesugen/caddy/Caddyfile:/etc/caddy/Caddyfile:ro
    environment:
      - PUID=1000
      - PGID=1000
    networks:
      - caddy_net
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      update_config:
        parallelism: 1
        delay: 10s
        order: start-first
      restart_policy:
        condition: any
        delay: 5s
        max_attempts: 3

  # Cloudflare Tunnel
  cloudflared:
    image: cloudflare/cloudflared:2023.8.0
    command: tunnel run
    environment:
      - PUID=1000
      - PGID=1000
    volumes:
      - /mnt/yesugen/cloudflared:/etc/cloudflared
    networks:
      - caddy_net
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      restart_policy:
        condition: any
        delay: 5s
        max_attempts: 3
    secrets:
      - tunnel_token

volumes:
  caddy_data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=10.0.0.10,nfsvers=4,rw,soft,noatime,nodiratime
      device: ":/flash/yesugen/caddy/data"
  caddy_config:
    driver: local
    driver_opts:
      type: nfs
      o: addr=10.0.0.10,nfsvers=4,rw,soft,noatime,nodiratime
      device: ":/flash/yesugen/caddy/config"

networks:
  caddy_net:
    external: true

secrets:
  tunnel_token:
    external: true
```

## Best Practices for Swarm Stack Files

1. **Always use specific image tags** (e.g., `nginx:1.25.1-alpine`) instead of `latest`
2. **Define update policies** to control how services are updated
3. **Use placement constraints** to control where services run
4. **Configure health checks** for services to enable automatic healing
5. **Use configs and secrets** instead of environment variables for sensitive data
6. **Set resource limits** to prevent a single service from consuming all resources
7. **Use NFS volumes** for persistent data across the swarm
8. **Organize services into multiple stacks** by function (e.g., monitoring, media, databases)
9. **Create separate overlay networks** for isolation between service groups
10. **Document your stacks** with comments in the YAML files

Following these practices will help you maintain a stable, secure, and manageable Docker Swarm environment.
