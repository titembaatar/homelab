#!/usr/bin/env bash
# desc: Clones a VM from template and configures hostname/network
set -e

vm_template_id="9000"
new_vm_id=$1
name=$2
target=$3
host=$(hostname)

show_progress() {
  local duration=$1
  local message="${2:-Waiting}"
  local bar_length=20

  for ((i=0; i<=duration; i++)); do
    local progress=$((i * bar_length / duration))
    local remaining=$((duration - i))

    local bar=""
    for ((j=0; j<bar_length; j++)); do
      if ((j < progress)); then
        bar+="="
      else
        bar+=" "
      fi
    done

    printf "\r%s\n[%s] %02ds remaining..." "$message" "$bar" "$remaining"

    if ((i < duration)); then
      printf "\033[1A"
    fi

    sleep 1
  done

  printf "\r%s\n[%s] Complete!     \n" "$message" "$(printf "%${bar_length}s" | tr ' ' '=')"
}

ssh_key_path="$HOME/.ssh/mukhulai.pub"
ssh_user="titem"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <new_vm_id> <name> [target_host]"
  exit 1
fi

if ! command -v qm &> /dev/null; then
  echo "[ERROR] Proxmox 'qm' command not found"
  exit 1
fi

if ! qm status "$vm_template_id" >/dev/null 2>&1; then
  echo "[ERROR] Template VM $vm_template_id not found"
  exit 1
fi

if [[ ! -f "$ssh_key_path" ]]; then
  echo "[ERROR] SSH key not found at $ssh_key_path"
  echo "Run vm_template.sh first to generate required SSH keys"
  exit 1
fi

echo "Cloning VM $vm_template_id to $new_vm_id ($name)..."

clone_cmd="qm clone $vm_template_id $new_vm_id --full true --name $name"
if ! $clone_cmd; then
  echo "[ERROR] Failed to clone VM"
  exit 1
fi

mac_address=$(grep 'net0:' "/etc/pve/nodes/$host/qemu-server/$new_vm_id.conf" | awk '{print $2}' | sed 's/virtio=\([^,]*\),bridge=.*/\1/')

if [[ -z "$mac_address" ]]; then
  echo "[ERROR] Could not extract MAC address from VM config"
  exit 1
fi

echo "VM '$new_vm_id' ('$name') MAC address: $mac_address"
echo -n "Enter the IP address you assigned: "
read -r IP_ADDR

if [[ ! "$IP_ADDR" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
  echo "[ERROR] Invalid IP address format"
  exit 1
fi

echo "Starting VM $new_vm_id..."
if ! pvesh create "/nodes/$host/qemu/$new_vm_id/status/start"; then
  echo "[ERROR] Failed to start VM"
  exit 1
fi

show_progress 30 "Waiting for VM to boot"

ssh_cmd="ssh -i $ssh_key_path -o StrictHostKeyChecking=no -o ConnectTimeout=10 $ssh_user@$IP_ADDR"
scp_cmd="scp -i $ssh_key_path -o StrictHostKeyChecking=no -o ConnectTimeout=10"

echo "Configuring hostname and network..."

cat << EOF > /tmp/hosts.new
127.0.0.1 localhost
$IP_ADDR  $name.lan $name

::1       localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters
EOF

if ! $ssh_cmd "sudo mv /etc/hosts /etc/hosts.bak"; then
  echo "[ERROR] Failed to backup /etc/hosts"
  exit 1
fi

if ! $scp_cmd /tmp/hosts.new "$ssh_user@$IP_ADDR:/tmp/hosts.new"; then
  echo "[ERROR] Failed to copy hosts file"
  exit 1
fi

if ! $ssh_cmd "sudo mv /tmp/hosts.new /etc/hosts"; then
  echo "[ERROR] Failed to update /etc/hosts"
  exit 1
fi

if ! $ssh_cmd "sudo hostnamectl set-hostname '$name'"; then
  echo "[ERROR] Failed to set hostname"
  exit 1
fi

rm -f /tmp/hosts.new

echo "Verifying configuration..."
echo "Hostname: $($ssh_cmd "hostname" 2>/dev/null || echo "Failed to get hostname")"
echo "/etc/hostname: $($ssh_cmd "cat /etc/hostname" 2>/dev/null || echo "Failed to read /etc/hostname")"

echo "Removing cloud-init configuration..."
if ! qm set "$new_vm_id" --delete ide2; then
  echo "[WARN ] Failed to remove cloud-init drive"
fi

if ! qm stop "$new_vm_id"; then
  echo "[WARN ] Failed to stop VM"
fi

if ! qm start "$new_vm_id"; then
  echo "[WARN ] Failed to start VM"
fi

show_progress 5 "Waiting for VM to boot"

if [[ -n "$target" ]]; then
  echo "Migrating VM $new_vm_id to $target..."
  if ! qm migrate "$new_vm_id" "$target"; then
    echo "[ERROR] Failed to migrate VM to $target"
    exit 1
  fi
  echo "VM migrated to $target successfully"
fi

echo "VM $new_vm_id ($name) cloned, configured and started successfully!"

exit 0
