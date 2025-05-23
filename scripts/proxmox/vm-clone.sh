#!/usr/bin/env bash
# desc: Clones a VM from template and configures hostname/network
set -e

VM_TEMPLATE_ID="9000"
NEW_VM_ID=$1
NAME=$2
TARGET=$3
HOST=$(hostname)

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

SSH_KEY_PATH="$HOME/.ssh/mukhulai.pub"
SSH_USER="titem"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <new_vm_id> <name> [target_host]"
  exit 1
fi

if ! command -v qm &> /dev/null; then
  echo "[ERROR] Proxmox 'qm' command not found"
  exit 1
fi

if ! qm status "$VM_TEMPLATE_ID" >/dev/null 2>&1; then
  echo "[ERROR] Template VM $VM_TEMPLATE_ID not found"
  exit 1
fi

if [[ ! -f "$SSH_KEY_PATH" ]]; then
  echo "[ERROR] SSH key not found at $SSH_KEY_PATH"
  echo "Run vm-template.sh first to generate required SSH keys"
  exit 1
fi

echo "Cloning VM $VM_TEMPLATE_ID to $NEW_VM_ID ($NAME)..."

CLONE_CMD="qm clone $VM_TEMPLATE_ID $NEW_VM_ID --full true --name $NAME"
if ! $CLONE_CMD; then
  echo "[ERROR] Failed to clone VM"
  exit 1
fi

MAC_ADDRESS=$(grep 'net0:' "/etc/pve/nodes/$HOST/qemu-server/$NEW_VM_ID.conf" | awk '{print $2}' | sed 's/virtio=\([^,]*\),bridge=.*/\1/')

if [[ -z "$MAC_ADDRESS" ]]; then
  echo "[ERROR] Could not extract MAC address from VM config"
  exit 1
fi

echo "VM '$NEW_VM_ID' ('$NAME') MAC address: $MAC_ADDRESS"
echo -n "Enter the IP address you assigned: "
read -r IP_ADDR

if [[ ! "$IP_ADDR" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
  echo "[ERROR] Invalid IP address format"
  exit 1
fi

echo "Starting VM $NEW_VM_ID..."
if ! pvesh create "/nodes/$HOST/qemu/$NEW_VM_ID/status/start"; then
  echo "[ERROR] Failed to start VM"
  exit 1
fi

show_progress 30 "Waiting for VM to boot"

SSH_CMD="ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no -o ConnectTimeout=10 $SSH_USER@$IP_ADDR"
SCP_CMD="scp -i $SSH_KEY_PATH -o StrictHostKeyChecking=no -o ConnectTimeout=10"

echo "Configuring hostname and network..."

cat << EOF > /tmp/hosts.new
127.0.0.1 localhost
$IP_ADDR  $NAME.lan $NAME

::1       localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters
EOF

if ! $SSH_CMD "sudo mv /etc/hosts /etc/hosts.bak"; then
  echo "[ERROR] Failed to backup /etc/hosts"
  exit 1
fi

if ! $SCP_CMD /tmp/hosts.new "$SSH_USER@$IP_ADDR:/tmp/hosts.new"; then
  echo "[ERROR] Failed to copy hosts file"
  exit 1
fi

if ! $SSH_CMD "sudo mv /tmp/hosts.new /etc/hosts"; then
  echo "[ERROR] Failed to update /etc/hosts"
  exit 1
fi

if ! $SSH_CMD "sudo hostnamectl set-hostname '$NAME'"; then
  echo "[ERROR] Failed to set hostname"
  exit 1
fi

rm -f /tmp/hosts.new

echo "Verifying configuration..."
echo "Hostname: $($SSH_CMD "hostname" 2>/dev/null || echo "Failed to get hostname")"
echo "/etc/hostname: $($SSH_CMD "cat /etc/hostname" 2>/dev/null || echo "Failed to read /etc/hostname")"

echo "Removing cloud-init configuration..."
if ! qm set "$NEW_VM_ID" --delete ide2; then
  echo "[WARN ] Failed to remove cloud-init drive"
fi

if ! qm stop "$NEW_VM_ID"; then
  echo "[WARN ] Failed to stop VM"
fi

if ! qm start "$NEW_VM_ID"; then
  echo "[WARN ] Failed to start VM"
fi

show_progress 5 "Waiting for VM to boot"

if [[ -n "$TARGET" ]]; then
  echo "Migrating VM $NEW_VM_ID to $TARGET..."
  if ! qm migrate "$NEW_VM_ID" "$TARGET"; then
    echo "[ERROR] Failed to migrate VM to $TARGET"
    exit 1
  fi
  echo "VM migrated to $TARGET successfully"
fi

echo "VM $NEW_VM_ID ($NAME) cloned, configured and started successfully!"

exit 0
