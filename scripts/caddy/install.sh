#!/bin/bash
set -e

# Default values
HOST_IP=""
DOMAIN=""
EMAIL=""
CF_API_TOKEN=""
USE_STAGING=true

# Function to prompt for confirmation
confirm() {
	read -p "$1 [y/n]: " -n 1 -r
	echo
	[[ $REPLY =~ ^[Yy]$ ]]
}

# Get Host IP address
get_host_ip () {
	HOST_IP=$(ip a show eth0 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
	echo "$HOST_IP"
}

# Create required directories
create_directories() {
	echo "Creating directory structure..."
	
	# Creating directories
	mkdir -p /config/homelab/{compose/caddy/build,volumes/caddy/{config,data/acme}}
	
	# Set permissions
	sudo chown -R "$(id -u):$(id -g)" /config/homelab/compose/caddy
	sudo chown -R "$(id -u):$(id -g)" /config/homelab/volumes/caddy
	sudo chmod 600 /config/homelab/volumes/caddy/data/acme
	
	echo "Directories created."
}

# Create Dockerfile
create_dockerfile() {
	echo "Creating Dockerfile..."

	cat > /config/homelab/compose/caddy/build/Dockerfile << EOL
FROM caddy:2-builder AS builder
RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare
FROM caddy:2
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
VOLUME /data
VOLUME /config
EOL

	echo "Dockerfile created."
}

# Create environment file
create_caddyfile() {
	echo "Creating Caddyfile..."

	local acme_ca="https://acme-v02.api.letsencrypt.org/directory"
	if [ "$USE_STAGING" = true ]; then
		acme_ca="https://acme-staging-v02.api.letsencrypt.org/directory"
	fi
	
	cat > /config/homelab/compose/caddy/Caddyfile << EOL
{
	email {env.CF_EMAIL}
	acme_dns cloudflare {env.CF_API_TOKEN}
	acme_ca "${acme_ca}"
}

*.${DOMAIN} {
	tls {
		dns cloudflare {env.CF_API_TOKEN}
	}
}

caddy.${DOMAIN} {
	respond "Caddy is running."
}
EOL

	echo "Caddyfile created."
}

# Create environment file
create_caddy_env() {
	echo "Creating Caddy .env file..."
	
	cat > /config/homelab/compose/caddy/.env << EOL
CF_API_TOKEN=${CF_API_TOKEN}
CF_EMAIL=${EMAIL}
EOL
    
	echo "Caddy .env file created."
}

# Create docker-compose.yml
create_caddy_docker_compose() {
	echo "Creating Caddy docker-compose.yml..."
	
	cat > /config/homelab/compose/caddy/docker-compose.yml << EOL
services:
  caddy:
    build:
      dockerfile: ./build/Dockerfile
    container_name: caddy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - /config/homelab/volumes/caddy/data:/data
      - /config/homelab/volumes/caddy/config:/config
    env_file:
      - ./.env
    restart: unless-stopped
    networks:
      - proxy

networks:
  proxy:
    external: true
EOL
    
	echo "Caddy docker-compose.yml created."
}

# Create Docker network
create_docker_network() {
	echo "Creating Docker network 'proxy'..."
	if docker network inspect proxy &>/dev/null; then
		echo "Docker network 'proxy' already exists."
		return 0
	fi

	docker network create proxy
	echo "Docker network 'proxy' created."
}

# Start Caddy
start_caddy() {
	echo "Starting Caddy..."
	cd /config/homelab/compose/caddy
	
	if ! docker compose up -d; then
		echo "Failed to start Caddy. Check logs for details."
		exit 1
	fi

	echo "Caddy started successfully."
}

# Collect user input for configuration
collect_information() {
	HOST_IP=$(get_host_ip)
	echo "====== Caddy installer ======"
	echo "This script will set up Caddy on host $HOST_IP."
	echo
	
	# Ask for primary domain
	read -rp "Enter your primary domain name (e.g., mydomain.com): " input_domain
	[[ -n "$input_domain" ]] && DOMAIN=$input_domain
	
	# Ask for cloudlare email
	read -rp "Enter your Cloudflare email : " input_email
	[[ -n "$input_email" ]] && EMAIL=$input_email
	
	# Cloudflare DNS configuration
	read -rp "Enter your Cloudflare API Token: " input_cf_token
	[[ -n "$input_cf_token" ]] && CF_API_TOKEN=$input_cf_token

	# Confirm staging environment
	if ! confirm "Do you want to use Let's Encrypt staging environment ? (recommended)"; then
		USE_STAGING=false
	fi
	
	# Confirm information
	echo
	echo "====== Configuration Summary ======"
	echo "Domain: $DOMAIN"
	echo "Email: $EMAIL"
	echo "Clouflare API token: $CF_API_TOKEN"
	echo
	
	if ! confirm "Is this correct? Continue with installation?"; then
		echo "Installation cancelled."
		exit 1
	fi
}

# Main function
main() {
	collect_information
	echo
	echo "====== Starting script ======"
	create_directories
	create_dockerfile
	create_caddyfile
	create_caddy_env
	create_caddy_docker_compose
	create_docker_network
	if ! confirm "Do you want to start Caddy now?"; then
		echo
		echo "Caddy has been configured but not started."
	fi
	start_caddy 
	if [ "$USE_STAGING" = true ]; then
		echo
		echo "You are using Let's Encrypt staging environment,"
		echo "do not forget to switch to production when everything works."
		echo "You can update your Caddyfile and remove the \`acme_ca\` line"
	fi
	echo
	echo "=== Caddy has been installed and started. ==="
}

# Run main function
main
