#!/bin/bash
set -e

# Default values
APP_IP=""
APP_PORT=""
APP_NAME=""
DOMAIN="titem.top"
RELOADED=false
SKIP_PROMPT=false
SPECIAL_CASE=false

# Function to prompt for confirmation
confirm() {
	if [ "$SKIP_PROMPT" = true ]; then
		return 0
	fi

	read -p "$1 [y/n]: " -n 1 -r
	echo
	[[ $REPLY =~ ^[Yy]$ ]]
}

# Displat help
show_help() {
	echo "Usage: $0 [OPTIONS]"
	echo
	echo "Options:"
	echo "  --special-case    Add necessary config for special cases"
	echo "  --name NAME       Set the app name"
	echo "  --ip IP           Set the app IP address"
	echo "  --port PORT       Set the app port"
	echo "  --skip-prompt     Skip all prompts and confirmations"
	echo "  --help            Show this help message"
	echo
}

# Parse command-line arguments
parse_arguments() {
	while [ "$#" -gt 0 ]; do
		case "$1" in
			--special-case)
				SPECIAL_CASE=true
				shift 2
				;;
			--name)
				APP_NAME="$2"
				shift 2
				;;
			--ip)
				APP_IP="$2"
				shift 2
				;;
			--port)
				APP_PORT="$2"
				shift 2
				;;
			--skip-prompt)
				SKIP_PROMPT=true
				shift
				;;
			--help)
				show_help
				exit 0
				;;
			*)
				echo "Unknown option: $1"
				show_help
				exit 1
				;;
		esac
	done

	# Check if all required parameters are provided when skipping prompts
	if [ "$SKIP_PROMPT" = true ]; then
		if [ -z "$APP_NAME" ] || [ -z "$APP_IP" ] || [ -z "$APP_PORT" ]; then
			echo "Error: When using --skip-prompt, you must provide --name, --ip, and --port."
			exit 1
		fi
	fi
}

# Create environment file
update_caddyfile() {
	echo "Backing up Caddyfile..."

	local	Caddyfile="/config/homelab/compose/caddy/Caddyfile"
	cp "$Caddyfile" "${Caddyfile}.bak"

	echo "Caddyfile backed up."
	echo "Updating Caddyfile..."
	
	if [ $SPECIAL_CASE = true ]; then
		cat >> "$Caddyfile" << EOL

${APP_NAME}.${DOMAIN} {
	reverse_proxy "${APP_IP}:${APP_PORT}" {
    transport http {
      tls_insecure_skip_verify
    }
  }
}
EOL

		echo "Caddyfile updated."
		return 0
	fi
	cat >> "$Caddyfile" << EOL

${APP_NAME}.${DOMAIN} {
	reverse_proxy "${APP_IP}:${APP_PORT}"
}
EOL

	echo "Caddyfile updated."
}

# Start Caddy
reload_caddy() {
	echo "Reloading Caddy..."
	if ! docker exec caddy caddy reload --config /etc/caddy/Caddyfile; then
		echo "Failed to reload Caddy."
		return 1
	fi

	RELOADED=true
	echo "Caddy reloaded."
}

# Collect user input for configuration
collect_information() {
	if [ "$SKIP_PROMPT" = true ]; then
		return
	fi

	echo "====== Add Application to Caddyfile ======"
	echo
	echo "This script will update the Caddyfile."
	echo "A backup \`Caddyfile.bak\` will be created."
	echo
	
	# Ask for app domain
	read -rp "Enter the name for your app: " input_name
	[[ -n "$input_name" ]] && APP_NAME=$input_name
	
	# Ask for app ip
	read -rp "Enter the IP address of your app: " input_ip
	[[ -n "$input_ip" ]] && APP_IP=$input_ip
	
	# Ask for app port
	read -rp "Enter the port of your app: " input_port
	[[ -n "$input_port" ]] && APP_PORT=$input_port
	
	# Confirm information
	echo
	echo "====== Summary ======"
	echo
	echo "Domain: $DOMAIN"
	echo "Name: $APP_NAME"
	echo "IP: $APP_IP"
	echo "Port: $APP_PORT"
	echo
	
	if ! confirm "Is this correct? Continue with installation?"; then
		echo "Installation cancelled."
		exit 1
	fi
}

# Main function
main() {
	parse_arguments "$@"
	collect_information
	echo
	echo "====== Starting script ======"
	echo
	echo "Adding ${APP_NAME}.${DOMAIN} with IP ${APP_IP} and port ${APP_PORT}"
	update_caddyfile
	reload_caddy 
	if [ "$RELOADED" = false ]; then
		echo "Caddy not reloaded. Reload manually to"
		echo "propagate the changes. You can run:"
		echo "docker exec caddy caddy reload --config /etc/caddy/Caddyfile"
	fi
	echo
	echo "=== Caddyfile updated and config reloaded ==="
	echo
}

# Run main function
main "$@"
