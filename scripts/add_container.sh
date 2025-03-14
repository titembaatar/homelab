#!/bin/bash
set -e

# Default values
APP_NAME=""
APP_IMAGE=""
APP_PORTS=()
APP_ENV=()
APP_ENV_VALUE=()
APP_VOLUMES=()
PROXY_PORT=""
D_PATH="/config/homelab"
USE_VAULT=true
HOST_IP=$(ip a show eth0 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)

# Function to prompt for confirmation
confirm() {
	read -p "$1 [y/n]: " -n 1 -r
	echo
	[[ $REPLY =~ ^[Yy]$ ]]
}

# Create environment file
create_directories() {
	echo "Creating directories..."

	mkdir -p "${D_PATH}/compose/${APP_NAME}"
	mkdir -p "${D_PATH}/volumes/${APP_NAME}"
	for volume in "${APP_VOLUMES[@]}"; do
		mkdir -p "${D_PATH}/volumes/${APP_NAME}/${volume}"
	done

	touch "${D_PATH}/compose/${APP_NAME}/.env"
	touch "${D_PATH}/compose/${APP_NAME}/docker-compose.yml"

	echo "Directories created."
}

create_env() {
	echo "Creating .env file..."

	cat > "${D_PATH}/compose/${APP_NAME}/.env" << EOL
PUID=1000
PGID=1000
TZ=Europe/Paris
EOL

	if [[ ${#APP_ENV[@]} != 0 ]]; then
		for i in "${!APP_ENV[@]}"; do
			cat >> "${D_PATH}/compose/${APP_NAME}/.env" << EOL
${APP_ENV[$i]}=${APP_ENV_VALUE[$i]}
EOL
		done
	fi

	echo ".env file created."
}

create_docker_compose() {
	echo "Creating docker-compose.yml file..."

	cat > "${D_PATH}/compose/${APP_NAME}/docker-compose.yml" << EOL
services:
  ${APP_NAME}:
    container_name: ${APP_NAME}
    image: ${APP_IMAGE}
    env_file:
      - path: ./.env
    networks:
      - proxy
    restart: unless-stopped
    ports:
EOL

	for port in "${APP_PORTS[@]}"; do
		cat >> "${D_PATH}/compose/${APP_NAME}/docker-compose.yml" << EOL
      - "${port}:${port}"
EOL
	done

	cat >> "${D_PATH}/compose/${APP_NAME}/docker-compose.yml" << EOL
    volumes:
EOL

	if [ $USE_VAULT = true ]; then
		cat >> "${D_PATH}/compose/${APP_NAME}/docker-compose.yml" << EOL
      - /vault:/data
EOL
	fi

	for volume in "${APP_VOLUMES[@]}"; do
		cat >> "${D_PATH}/compose/${APP_NAME}/docker-compose.yml" << EOL
      - ${D_PATH}/volumes/${APP_NAME}/${volume}:/${volume}
EOL
	done

	cat >> "${D_PATH}/compose/${APP_NAME}/docker-compose.yml" << EOL

networks:
  proxy:
    external: true
EOL

	echo "docker-compose.yml file created."
}

start_container() {
	echo "Starting container..."
	echo
	docker compose -f "${D_PATH}/compose/${APP_NAME}/docker-compose.yml" up -d
	echo
	echo "Container started."
}

# Collect user input for configuration
collect_information() {
	echo
	echo "====== Setup a new container ======"
	echo
	echo "This script will :"
	echo "  1. Create directories for compose/ and volumes/"
	echo "  2. Create necessary files for Docker compose"
	echo
	
	# Ask for container name
	read -rp "Enter the container name : " input_name
	[[ -n "$input_name" ]] && APP_NAME=$input_name
	
	# Ask for container image
	read -rp "Enter the container image : " input_image
	[[ -n "$input_image" ]] && APP_IMAGE=$input_image
	
	# Ask for container ports
	read -rp "Enter the ports necessary (space separated): " input_ports
	read -ra APP_PORTS <<< "$input_ports"
	
	# Ask for environment variables and values
	if confirm "Do you want to add environment variables and values ?"; then
		while true; do
			read -rp "Enter the environment variable: " input_env_var
			APP_ENV+=("$input_env_var")

			read -rp "Enter the environment value: " input_env_val
			APP_ENV_VALUE+=("$input_env_val")

			if ! confirm "Add another environment entry ?"; then
				break
			fi
		done
	fi
	
	# Ask for container volumes
	read -rp "Enter the volumes necessary (space separated): " input_volumes
	read -ra APP_VOLUMES <<< "$input_volumes"
	
	# Ask for adding vault 
	if ! confirm "Use vault for this container ? :"; then
		USE_VAULT=false
	fi
	
	# Confirm information
	echo
	echo "====== Summary ======"
	echo
	echo "Name: $APP_NAME"
	echo "Image: $APP_IMAGE"
	echo "Ports:"
	for port in "${APP_PORTS[@]}"; do
		echo "  - $port"
	done
	echo "Environments:"
	for i in "${!APP_ENV[@]}"; do
		echo "  - ${APP_ENV[$i]}: ${APP_ENV_VALUE[$i]}"
	done
	echo "Volumes:"
	for volume in "${APP_VOLUMES[@]}"; do
		echo "  - $volume"
	done
	if [ $USE_VAULT = true ]; then
		echo "Using vault: yes"
	else
		echo "Using vault: no"
	fi
	echo
	
	if ! confirm "Is this correct? Continue with installation?"; then
		echo "Installation cancelled."
		exit 1
	fi
}

choose_port() {
	echo
	while true; do
		echo "Please select the port to use for proxy :"
		for port in "${APP_PORTS[@]}"; do
			echo "  - ${port}"
		done
		echo
		read -rp "Desired port : " selected_port

		port_found=false
		for port in "${APP_PORTS[@]}"; do
			if [[ "$port" == "$selected_port" ]]; then
				port_found=true
				break
			fi
		done

		if $port_found; then
			if confirm "Confirm the port ${selected_port}"; then
				PROXY_PORT="${selected_port}"
				break
			fi
		fi

		echo
		echo "Port not found in the list. Try again."
	done
}

add_to_proxy() {
	# Check if SSH key exists
	if ! [[ -f ~/.ssh/id_ed25519.pub ]]; then
		echo "Creating SSH key..."
		ssh-keygen -t ed25519
	fi
	
	# Check if proxy machine is known
	if ! grep -q 10.0.0.101 ~/.ssh/known_hosts; then
		echo "Propagating SSH key to proxy machine..."
		ssh-copy-id -i ~/.ssh/id_ed25519.pub titem@10.0.0.101
	fi

	# Check if there is multiple ports
	local proxy_port=""
	if [ ${#APP_PORTS[@]} = 1 ]; then
		proxy_port="${APP_PORTS[0]}"
	elif [ ${#APP_PORTS[@]} = 0 ]; then
		echo "No port, aborting..."
		exit 1
	else
		choose_port
		proxy_port="$PROXY_PORT"
	fi

	SSH_COMMAND="ssh titem@10.0.0.101 ${D_PATH}/scripts/caddy/add_app.sh \\
		--name \"${APP_NAME}\" \\
		--ip \"${HOST_IP}\" \\
		--port \"${proxy_port}\" \\
		--skip-prompt"

	if ! eval "$SSH_COMMAND"; then
		echo "Failed to add ${APP_NAME} to proxy. Please check the logs."
	fi

	echo "Successfully added ${APP_NAME} to proxy!"
	echo "Application is now accessible at ${APP_NAME}.titem.top"
}

# Main function
main() {
	collect_information
	echo
	echo "====== Starting script ======"
	echo
	create_directories 
	create_env
	create_docker_compose
	echo
	if confirm "Do you want to start container ?"; then
		start_container 
	fi
	echo
	echo "=== Container setup finished ==="
	echo
	if confirm "Do you want to add this container to proxy ? :"; then
		add_to_proxy
	fi
}

# Run main function
main
