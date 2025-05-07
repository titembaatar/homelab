#!/bin/bash
set -e

# Config
VM_ID=9000
VM_NAME="debian-template"
STORAGE="moge_khatun"
ISO_STORAGE="/mnt/pve/moge_khatun/template/iso/"
MEMORY=4096
CORES=2
DISK_SIZE="16G"
BRIDGE="vmbr0"
CLOUD_IMG_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
CLOUD_IMG="debian-12-genericcloud-amd64.iso"
USER_NAME="titem"

if ! command -v mkpasswd &> /dev/null; then
  echo "mkpasswd not found. Install 'whois' package (apt install whois). Exiting."
  exit 2
fi

echo -n "Enter password for user '$USER_NAME': "
read -s USER_PASSWORD
echo
echo -n "Confirm password for user '$USER_NAME': "
read -s CONFIRM_USER_PASSWORD
echo
if [ "$USER_PASSWORD" = "$CONFIRM_USER_PASSWORD" ]; then
  PWD_HASH=$(mkpasswd --method=SHA-512 --rounds=4096 -s "$USER_PASSWORD")
else
  echo "Password doesn't match."
  exit 2
fi

echo -n "Enter SSH key (cat ~/.ssh/id_ed25519.pub | wl-copy): "
read SSH_KEY
echo

USER_DATA_FILE="/mnt/pve/moge_khatun/snippets/userconfig.yaml"
cat << EOF > $USER_DATA_FILE
#cloud-config
keyboard:
  layout: us
locale: en_US.UTF-8
timezone: Europe/Paris
hostname: $VM_NAME
users:
  - name: root
    passwd: $PWD_HASH
  - name: $USER_NAME
    groups: sudo
    passwd: $PWD_HASH
    ssh_authorized_keys:
      - $SSH_KEY
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
package_update: true
packages:
  - sudo
  - qemu-guest-agent
runcmd:
  - systemctl enable --now qemu-guest-agent
EOF


if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Exiting."
  exit 1
fi

if ! command -v qm &> /dev/null; then
  echo "Proxmox 'qm' command not found. Exiting."
  exit 1
fi

if [[ ! -f "$ISO_STORAGE$CLOUD_IMG" ]]; then
  echo "Downloading Debian 12 cloud image..."
  wget -O $ISO_STORAGE$CLOUD_IMG $CLOUD_IMG_URL || {
    echo "Failed to download cloud image. Exiting."
    exit 1
  }
fi

echo "Creating VM $VM_ID ($VM_NAME)..."
qm create $VM_ID \
  --name $VM_NAME \
  --memory $MEMORY \
  --balloon 0 \
  --cores $CORES \
  --cpu host \
  --numa 1 \
  --net0 virtio,bridge=$BRIDGE \
  --agent 1 \
  --ostype l26 || {
    echo "Failed to create VM. Exiting."
    exit 1
  }

echo "Importing cloud image to VM $VM_ID..."
qm importdisk $VM_ID $ISO_STORAGE$CLOUD_IMG $STORAGE || {
  echo "Failed to import disk. Exiting."
  exit 1
}

echo "Configuring disk, cloud-init, and IP..."
qm set $VM_ID \
  --scsihw virtio-scsi-pci \
  --scsi0 "$STORAGE:$VM_ID/vm-$VM_ID-disk-0.raw,ssd=1" \
  --ide2 $STORAGE:cloudinit \
  --boot c \
  --bootdisk scsi0 \
  --serial0 socket \
  --vga serial0 \
  --ipconfig0 ip=dhcp \
  --cicustom "user=$STORAGE:snippets/userconfig.yaml" || {
    echo "Failed VM configuration. Exiting."
    exit 1
  }

echo "Resizing disk to $DISK_SIZE..."
qm disk resize $VM_ID scsi0 $DISK_SIZE || {
  echo "Failed to resize disk. Exiting."
  exit 1
}


read -rp "Convert VM $VM_ID to a template? (y/n): " CONVERT
if [[ $CONVERT == "y" ]]; then
  echo "Converting VM $VM_ID to template..."
  qm template $VM_ID || {
    echo "Failed to convert to template. Exiting."
    exit 1
  }
  echo "Template created successfully!"
else
  echo "VM $VM_ID created successfully! Not converted to template."
fi

exit 0
