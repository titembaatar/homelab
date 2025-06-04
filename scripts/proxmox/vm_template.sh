#!/usr/bin/env bash
# desc: Creates a VM template on Proxmox using Debian cloud image with SSH key setup
set -e

vm_id=9000
vm_name="debian-template"
vm_memory=4096
vm_cores=2
vm_disk_size="16G"
vm_net_bridge="vmbr0"
vm_storage="moge_khatun"
username="titem"

cloud_img_url="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
cloud_img="debian-12-genericcloud-amd64.iso"
cloud_iso="/mnt/pve/moge_khatun/template/iso/"
user_data="/mnt/pve/moge_khatun/snippets/userconfig.yaml"

chingis_ssh_key_path="$HOME/.ssh/chingis.pub"
mukhulai_ssh_key_path="/root/.ssh/mukhulai.pub"

usage() {
  cat << EOF
Usage: $0 [OPTIONS]

Options:
  -i, --vm-id ID          VM ID (default: $vm_id)
  -n, --name NAME         VM name (default: $vm_name)
  -u, --user USER         Default user (default: $username)
  -k, --ssh-key PATH      Path to main machine SSH public key (default: $chingis_ssh_key_path)
  -h, --help              Show this help message
EOF
  exit 0
}

ensure_mukhulai_ssh_key() {
  local key_path="$mukhulai_ssh_key_path"
  local private_key="${key_path%.pub}"

  if [[ ! -f "$key_path" ]]; then
    echo "Mukhulai SSH key not found, generating new key pair..."
    mkdir -p "$(dirname "$private_key")"
    ssh-keygen -t ed25519 -f "$private_key" -N "" -C "root@mukhulai"
    echo "Mukhulai SSH key generated: $key_path"
  fi
}

read_mukhulai_ssh_key() {
  local key_path="$mukhulai_ssh_key_path"

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
      vm_id="$2"
      shift 2
      ;;
    -n|--name)
      vm_name="$2"
      shift 2
      ;;
    -u|--user)
      username="$2"
      shift 2
      ;;
    -k|--ssh-key)
      chingis_ssh_key_path="$2"
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

validate_chingis_ssh_key "$chingis_ssh_key_path"
ensure_mukhulai_ssh_key

chingis_ssh_key=$(cat "$chingis_ssh_key_path")
mukhulai_ssh_key=$(read_mukhulai_ssh_key)

echo "Creating VM $vm_id ($vm_name) with user: $username"

cat << EOF > "$user_data"
#cloud-config
keyboard:
  layout: us
locale: en_US.UTF-8
timezone: Europe/Paris
hostname: $vm_name
preserve_hostname: true
users:
  - name: root
    shell: /bin/bash
  - name: $username
    groups: sudo
    ssh_authorized_keys:
      - $chingis_ssh_key
      - $mukhulai_ssh_key
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    shell: /bin/bash
package_update: true
packages:
  - sudo
  - qemu-guest-agent
runcmd:
  - systemctl enable --now qemu-guest-agent
EOF

if [[ ! -f "$cloud_iso$cloud_img" ]]; then
  echo "Downloading Debian 12 cloud image..."
  wget -O "$cloud_iso$cloud_img" "$cloud_img_url" || {
    echo "[ERROR] Failed to download cloud image"
      exit 1
    }
fi

echo "Creating VM $vm_id ($vm_name)..."
qm create "$vm_id" \
  --name "$vm_name" \
  --memory "$vm_memory" \
  --balloon 0 \
  --cores "$vm_cores" \
  --cpu host \
  --numa 1 \
  --net0 "virtio,bridge=$vm_net_bridge" \
  --agent 1 \
  --ostype l26 || {
    echo "[ERROR] Failed to create VM"
    exit 1
  }

echo "Importing cloud image to VM $vm_id..."
qm importdisk "$vm_id" "$cloud_iso$cloud_img" "$vm_storage" || {
  echo "[ERROR] Failed to import disk"
  exit 1
}

echo "Configuring VM $vm_id..."
qm set "$vm_id" \
  --scsihw virtio-scsi-pci \
  --scsi0 "$vm_storage:$vm_id/vm-$vm_id-disk-0.raw,ssd=1" \
  --ide2 "$vm_storage:cloudinit" \
  --boot c \
  --bootdisk scsi0 \
  --serial0 socket \
  --vga serial0 \
  --ipconfig0 ip=dhcp \
  --cicustom "user=$vm_storage:snippets/userconfig.yaml" || {
    echo "[ERROR] Failed to configure VM"
    exit 1
  }

echo "Resizing disk to $vm_disk_size..."
qm disk resize "$vm_id" scsi0 "$vm_disk_size" || {
  echo "[ERROR] Failed to resize disk"
  exit 1
}

echo "Converting VM $vm_id to template..."
qm template "$vm_id" || {
  echo "[ERROR] Failed to convert to template"
  exit 1
}

echo "Template $vm_id ($vm_name) created successfully!"

exit 0
