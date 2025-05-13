#!/usr/bin/env bash
set -e

# Config
VM_ID=9000
VM_NAME="debian-template"
VM_MEMORY=4096
VM_CORES=2
VM_DISK_SIZE="16G"
VM_NET_BRIDGE="vmbr0"
VM_STORAGE="moge_khatun"

CLOUD_IMG_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
CLOUD_IMG="debian-12-genericcloud-amd64.iso"
CLOUD_ISO_PATH="/mnt/pve/moge_khatun/template/iso/"

USER_NAME="titem"
SSH_KEY1=""

USER_DATA_FILE="/mnt/pve/moge_khatun/snippets/userconfig.yaml"
cat << EOF > $USER_DATA_FILE
#cloud-config
keyboard:
  layout: us
locale: en_US.UTF-8
timezone: Europe/Paris
hostname: $VM_NAME
preserve_hostname: true
users:
  - name: root
    shell: /bin/bash
  - name: $USER_NAME
    groups: sudo
    ssh_authorized_keys:
      - $SSH_KEY1
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    shell: /bin/bash
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

if [[ ! -f "$CLOUD_ISO_PATH$CLOUD_IMG" ]]; then
  echo "Downloading Debian 12 cloud image..."
  wget -O $CLOUD_ISO_PATH$CLOUD_IMG $CLOUD_IMG_URL || {
    echo "Failed to download cloud image. Exiting."
    exit 1
  }
fi

echo "Creating VM $VM_ID ($VM_NAME)..."
qm create $VM_ID \
  --name $VM_NAME \
  --memory $VM_MEMORY \
  --balloon 0 \
  --cores $VM_CORES \
  --cpu host \
  --numa 1 \
  --net0 virtio,bridge=$VM_NET_BRIDGE \
  --agent 1 \
  --ostype l26 || {
    echo "Failed to create VM. Exiting."
    exit 1
  }

echo "Importing cloud image to VM $VM_ID..."
qm importdisk $VM_ID $CLOUD_ISO_PATH$CLOUD_IMG $VM_STORAGE || {
  echo "Failed to import disk. Exiting."
  exit 1
}

echo "Configuring disk, cloud-init, and IP..."
qm set $VM_ID \
  --scsihw virtio-scsi-pci \
  --scsi0 "$VM_STORAGE:$VM_ID/vm-$VM_ID-disk-0.raw,ssd=1" \
  --ide2 $VM_STORAGE:cloudinit \
  --boot c \
  --bootdisk scsi0 \
  --serial0 socket \
  --vga serial0 \
  --ipconfig0 ip=dhcp \
  --cicustom "user=$VM_STORAGE:snippets/userconfig.yaml" || {
    echo "Failed VM configuration. Exiting."
    exit 1
  }

echo "Resizing disk to $VM_DISK_SIZE..."
qm disk resize $VM_ID scsi0 $VM_DISK_SIZE || {
  echo "Failed to resize disk. Exiting."
  exit 1
}


echo "Converting VM $VM_ID to template..."
qm template $VM_ID || {
  echo "Failed to convert to template. Exiting."
  exit 1
}
echo "Template created successfully!"

exit 0
