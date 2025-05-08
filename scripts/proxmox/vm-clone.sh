#!/bin/bash
set -e

VM_TEMPLATE_ID="9000"
NEW_VM_ID=$1
NAME=$2
HOST=$(hostname)
CLONE_CMD="qm clone $VM_TEMPLATE_ID $NEW_VM_ID --full true "
ARG_NAME="--name $NAME "

if [ "$NAME" != "" ]; then
  CLONE_CMD=$CLONE_CMD$ARG_NAME
fi

# Clone VM
$CLONE_CMD

# Change VM IP in DHCP
MAC_ADDRESS=$(grep 'net0:' /etc/pve/nodes/"$HOST"/qemu-server/"$NEW_VM_ID".conf | awk '{print $2}' | sed 's/virtio=\([^,]*\),bridge=.*/\1/')
echo "VM '$NEW_VM_ID' ('$NAME') MAC ADDRESS is '$MAC_ADDRESS'."
echo "Enter VM local IP address: "
read -r IP_ADDR
echo

# Start VM
pvesh create /nodes/"$HOST"/qemu/"$NEW_VM_ID"/status/start
echo "Starting VM, waiting 30s..."
for i in {01..30}; do
  printf "$i "
  sleep 1
done

# Change VM hostname
SSH_CMD="ssh -i $HOME/.ssh/mukhulai titem@$IP_ADDR sudo"
SCP_CMD="scp -i $HOME/.ssh/mukhulai /tmp/hosts.new titem@$IP_ADDR:/tmp/hosts.new"

cat << EOF > /tmp/hosts.new
127.0.0.1 localhost
$IP_ADDR  $NAME.lan $NAME

::1       localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters
EOF

$SSH_CMD mv /etc/hosts /etc/hosts.bak
$SCP_CMD
$SSH_CMD mv /tmp/hosts.new /etc/hosts
rm -f /tmp/hosts.new

$SSH_CMD hostnamectl set-hostname "$NAME"
$SSH_CMD hostname "$NAME"
$SSH_CMD echo "$NAME" > /etc/hostname

echo "new hostname : "
$SSH_CMD hostname
echo "/etc/hostname: "
$SSH_CMD cat /etc/hostname
echo "/etc/hosts: "
$SSH_CMD cat /etc/hosts

# Remove CloudInit
qm set "$NEW_VM_ID" --delete ide2
qm stop "$NEW_VM_ID"

exit 0

