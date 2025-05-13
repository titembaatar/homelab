# 🐋 Setup Docker VMs
These scripts facilitate the setup and management of my homelab environment.

## Script Components & Usage
### Docker Installation (`scripts/docker/debian-install.sh`)
* **Purpose:** Installs Docker Engine and related tools on Debian-based systems.
* **Features:**
    * Installs Docker CE, CLI, Containerd, and compose plugin
    * Adds the current user to the docker group
    * Installs Lazydocker for container management
    * Configures PATH and aliases

### Swarm Manager Setup (`scripts/docker/manager.sh`)
* **Purpose:** Initializes a Docker Swarm manager node to use an overlay network
* **Features:**
    * Automatically detects the node's IP address
    * Initializes a new Docker Swarm
    * Creates the `caddy_net` overlay network
    * Displays the worker join token

### Swarm Worker Setup (`scripts/docker/worker.sh`)
* **Purpose:** Joins a node to an existing Docker Swarm as a worker to use overlay network.
* **Parameters:**
    * `WORKER_TOKEN`: Token from the manager node
    * `MANAGER_IP`: IP address of a manager node
* **Features:**
    * Installs Docker (by calling `debian-install.sh`)
    * Joins the node to the Swarm as a worker
    * Verifies the `caddy_net` network exists
* **Example Usage:**
    ```bash
    bash /path/to/worker.sh "SWMTKN-1-xxxxxxxxxxxx" "10.0.0.30"
    ```

### Gateway Deployment (`scripts/docker/deploy/gateway.sh`)
* **Purpose:** Sets up the primary gateway services on a manager node.
* **Features:**
    * Installs Docker (via `debian-install.sh`)
    * Initializes a Swarm manager (via `manager.sh`)
    * Deploys Caddy reverse proxy
    * Deploys gateway services

### Service Deployment Scripts (`scripts/docker/deploy/{ger.sh,servarr.sh}`)
* **Purpose:** Deploy specific service stacks on worker nodes.
* **Parameters:**
    * `WORKER_TOKEN`: Token from the manager node
    * `MANAGER_IP`: IP address of a manager node
* **Available Scripts:**
    * `ger.sh`: Deploys the `ger` stack
    * `servarr.sh`: Deploys `*arr` stack
* **Example Usage:**
    ```bash
    bash /path/to/servarr.sh "SWMTKN-1-xxxxxxxxxxxx" "10.0.0.30"
    ```

## Script Dependencies
The scripts follow a hierarchical structure with dependencies:
```
debian-install.sh    # Docker installation (independent)
  |
manager.sh           # Swarm manager setup (depends on Docker)
  |                    |
  |                    |---- gateway.sh  # Gateway deployment
  |
worker.sh            # Swarm worker setup (depends on Docker & manager)
  |
  |---- ger.sh       # Service stack deployment
  |---- servarr.sh   # Media services deployment
```

## Homelab Deployment Workflow
### `gateway` VM :
```bash
sudo apt-get update
sudo apt-get install git
cd $HOME
git clone https://github.com/titembaatar/homelab.git
$HOME/homelab/scripts/deploy/gateway.sh
```

> [!INFO]
>
> Keep the docker worker join token and manager IP

### `servarr` VM :
```bash
sudo apt-get update
sudo apt-get install git
cd $HOME
git clone https://github.com/titembaatar/homelab.git
$HOME/homelab/scripts/deploy/servarr.sh <worker-join-token> <manager-ip>
```

### `ger` VM :
```bash
sudo apt-get update
sudo apt-get install git
cd $HOME
git clone https://github.com/titembaatar/homelab.git
$HOME/homelab/scripts/deploy/ger.sh <worker-join-token> <manager-ip>
```
