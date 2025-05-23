#!/usr/bin/env bash
# desc: Creates a VM template on Proxmox using Debian cloud image with SSH key setup
set -e

VM_ID=9000
VM_NAME="debian-template"
VM_MEMORY=4096
VM_CORES=2
VM_DISK_SIZE="16G"
VM_NET_BRIDGE="vmbr0"
VM_STORAGE="moge_khatun"
USER_NAME="titem"

CLOUD_IMG_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
CLOUD_IMG="debian-12-genericcloud-amd64.iso"
CLOUD_ISO_PATH="/mnt/pve/moge_khatun/template/iso/"
USER_DATA_FILE="/mnt/pve/moge_khatun/snippets/userconfig.yaml"

CHINGIS_SSH_KEY_PATH="$HOME/.ssh/chingis.pub"
MUKHULAI_SSH_KEY_PATH="/root/.ssh/mukhulai.pub"

usage() {
  cat << EOF
Usage: $0 [OPTIONS]

Options:
  -i, --vm-id ID          VM ID (default: $VM_ID)
  -n, --name NAME         VM name (default: $VM_NAME)
  -u, --user USER         Default user (default: $USER_NAME)
  -k, --ssh-key PATH      Path to main machine SSH public key (default: $CHINGIS_SSH_KEY_PATH)
  -h, --help              Show this help message
EOF
  exit 0
}

ensure_mukhulai_ssh_key() {
  local key_path="$MUKHULAI_SSH_KEY_PATH"
  local private_key="${key_path%.pub}"

  if [[ ! -f "$key_path" ]]; then
    echo "Mukhulai SSH key not found, generating new key pair..."
    mkdir -p "$(dirname "$private_key")"
    ssh-keygen -t ed25519 -f "$private_key" -N "" -C "root@mukhulai"
    echo "Mukhulai SSH key generated: $key_path"
  fi
}

read_mukhulai_ssh_key() {
  local key_path="$MUKHULAI_SSH_KEY_PATH"

  if [[ ! -f "$key_path" ]]; then
    echo "[ERROR] Mukhulai SSH key not found at $key_path"
    exit 1
  fi

  cat "$key_path"
}

validate_chingis_ssh_key() {
  local key_path="$1"

  if [[ ! -f "$key_path" ]]; then
    echo "[ERROR] Main machine SSH key not found at $key_path"
    echo "Please generate it first with: ssh-keygen -t ed25519 -f ${key_path%.pub} -C \"$(whoami)@chingis\""
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -i|--vm-id)
      VM_ID="$2"
      shift 2
      ;;
    -n|--name)
      VM_NAME="$2"
      shift 2
      ;;
    -u|--user)
      USER_NAME="$2"
      shift 2
      ;;
    -k|--ssh-key)
      CHINGIS_SSH_KEY_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] This script must be run as root"
  exit 1
fi

if ! command -v qm &> /dev/null; then
  echo "[ERROR] Proxmox 'qm' command not found"
  exit 1
fi

validate_chingis_ssh_key "$CHINGIS_SSH_KEY_PATH"
ensure_mukhulai_ssh_key

CHINGIS_SSH_KEY=$(cat "$CHINGIS_SSH_KEY_PATH")
MUKHULAI_SSH_KEY=$(read_mukhulai_ssh_key)

echo "Creating VM $VM_ID ($VM_NAME) with user: $USER_NAME"

cat << EOF > "$USER_DATA_FILE"
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
      - $CHINGIS_SSH_KEY
      - $MUKHULAI_SSH_KEY
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    shell: /bin/bash
package_update: true
packages:
  - sudo
  - qemu-guest-agent
runcmd:
  - systemctl enable --now qemu-guest-agent
EOF

if [[ ! -f "$CLOUD_ISO_PATH$CLOUD_IMG" ]]; then
  echo "Downloading Debian 12 cloud image..."
  wget -O "$CLOUD_ISO_PATH$CLOUD_IMG" "$CLOUD_IMG_URL" || {
    echo "[ERROR] Failed to download cloud image"
      exit 1
    }
fi

echo "Creating VM $VM_ID ($VM_NAME)..."
qm create "$VM_ID" \
  --name "$VM_NAME" \
  --memory "$VM_MEMORY" \
  --balloon 0 \
  --cores "$VM_CORES" \
  --cpu host \
  --numa 1 \
  --net0 "virtio,bridge=$VM_NET_BRIDGE" \
  --agent 1 \
  --ostype l26 || {
    echo "[ERROR] Failed to create VM"
    exit 1
  }

echo "Importing cloud image to VM $VM_ID..."
qm importdisk "$VM_ID" "$CLOUD_ISO_PATH$CLOUD_IMG" "$VM_STORAGE" || {
  echo "[ERROR] Failed to import disk"
  exit 1
}

echo "Configuring VM $VM_ID..."
qm set "$VM_ID" \
  --scsihw virtio-scsi-pci \
  --scsi0 "$VM_STORAGE:$VM_ID/vm-$VM_ID-disk-0.raw,ssd=1" \
  --ide2 "$VM_STORAGE:cloudinit" \
  --boot c \
  --bootdisk scsi0 \
  --serial0 socket \
  --vga serial0 \
  --ipconfig0 ip=dhcp \
  --cicustom "user=$VM_STORAGE:snippets/userconfig.yaml" || {
    echo "[ERROR] Failed to configure VM"
    exit 1
  }

echo "Resizing disk to $VM_DISK_SIZE..."
qm disk resize "$VM_ID" scsi0 "$VM_DISK_SIZE" || {
  echo "[ERROR] Failed to resize disk"
  exit 1
}

echo "Converting VM $VM_ID to template..."
qm template "$VM_ID" || {
  echo "[ERROR] Failed to convert to template"
  exit 1
}

echo "Template $VM_ID ($VM_NAME) created successfully!"

exit 0
