#!/bin/bash
set -e

# Default values
HOST_IP=$(ip a show eth0 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
TAILSCALE=true
PIHOLE=true
UDPGRO=true

# Function to prompt for confirmation
confirm() {
	read -p "$1 [y/n]: " -n 1 -r
	echo
	[[ $REPLY =~ ^[Yy]$ ]]
}

install_tailscale() {
	echo "Installing Tailscale..."

	# Install tailscale
	sudo dnf up -y
	sudo dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
	sudo dnf install -y tailscale
	sudo systemctl enable --now tailscaled

	echo "Tailscale installed."
}

install_pihole() {
	echo "Installing Pi-Hole..."

	# Install pihole
	curl -sSL https://install.pi-hole.net | bash

	echo "Pi-Hole installed."
}

# Enable IP forwarding and make it permanant
enable_firewall() {
	echo "Configuring firewall..."

	# Install firewalld and conf
	sudo dnf install -y firewalld
	sudo firewall-cmd --permanent --add-masquerade

	# Configure firewall
	if [[ -d "/etc/sysctl.d/" ]]; then
		echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
		echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
		sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
	else
		echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
		echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf
		sudo sysctl -p /etc/sysctl.conf
	fi

	echo "Firewall configured."
}

udp_gro_forwarding() {
	echo "Configuring UDP GRO forwarding..."

	sudo dnf install -y ethtool
	sudo ethtool -K eth0 rx-udp-gro-forwarding on
	sudo tee /etc/systemd/system/udp-gro-config.service > /dev/null <<EOL
[Unit]
Description=Configure UDP GRO Forwarding
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/ethtool -K eth0 rx-udp-gro-forwarding on
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOL

	sudo chmod 644 /etc/systemd/system/udp-gro-config.service
	sudo systemctl daemon-reload
	sudo systemctl enable --now udp-gro-config.service

	echo "UDP GRO forwarding configured."
}

service_status() {
  echo
	echo "========= Service status. ========="
	echo
	if $TAILSCALE; then
		sudo systemctl status tailscaled
	fi

	if $PIHOLE; then
		sudo pihole status
	fi

	if $UDPGRO; then
		sudo systemctl status udp-gro-config.service
	fi
	
	echo
}

tailscale_setup() {
	echo "========= Tailscale setup ========="
	echo
	sudo tailscale up --advertise-exit-node --advertise-routes=10.0.0.0/24 --accept-dns=false
	echo "Visit the url to add the LXC to the tailscale network."
	echo "In the tailscale admin console, click on the \`...\` of the LXC and"
	echo "in the \`Edit routes settings...\` menu,"
	echo "validate the \`subnet routes\` and the \`exit node\`."
	echo "Then go to \`DNS\` tab and add a nameserver with :"
	echo "  - the tailscale IP of the LXC ( \`tailscale ip -4\` )"
	echo "  - Check \`Override local DNS\`"
	echo
}

pihole_setup() {
	echo "======== Pihole setup. =========="
	echo
	echo "Admin page to \`https://${HOST_IP}/admin/\`."
	echo "Password displayed during installation."
	echo "You can generate a new password with :"
	echo "sudo pihole -a -p <new-password>"
	echo
	echo "You can add more allowlists/blocklists in the admin panel under \`Lists\`."
	echo "Recommended hagezi/dns-blocklists multi pro list"
	echo "Then you can run, to update pihole :"
	echo "sudo pihole -g"
	echo
}

# Collect user input for configuration
collect_information() {
	echo "======== Network installer ========"
	echo "This script will set up Tailscale and Pi-Hole on host $HOST_IP."
	echo

	if ! confirm "Do you want to install Tailscale ?"; then
		TAILSCALE=false
	fi
	
	if ! confirm "Do you want to install Pi-Hole ?"; then
		PIHOLE=false
	fi
	
	if ! confirm "Do you want to configure UDP GRO forwarding (recommended) ?"; then
		UDPGRO=false
	fi
	
	# Confirm information
	echo
	echo "====== Configuration Summary ======"
	echo
	echo "TAILSCALE: ${TAILSCALE}"
	echo "PIHOLE: ${PIHOLE}"
	echo "UDP GRO forwarding: ${UDPGRO}"
	echo
	
	if ! confirm "Is this correct? Continue with installation?"; then
		echo "Installation cancelled."
		exit 1
	fi
}

# Main function
main() {
	echo
	collect_information
	echo
	echo "========= Starting script ========="
	echo

	if $TAILSCALE; then
		install_tailscale
		enable_firewall
	fi

	if $PIHOLE; then
		install_pihole
	fi

	if $UDPGRO; then
		udp_gro_forwarding 
	fi

	service_status
	echo
	echo "===== Network has been setup. ====="
	echo

	if $TAILSCALE; then
		tailscale_setup
	fi

	if $PIHOLE; then
		pihole_setup
	fi
}

# Run main function
main
