#!/bin/bash
set -e

VM_TEMPLATE_ID=$1
NEW_VM_ID=$2
NAME=$3
TARGET=$4
HOST=$(hostname)
CMD="qm clone $VM_TEMPLATE_ID $NEW_VM_ID --full true "
ARG_NAME="--name $NAME "
ARG_TARGET="--target $TARGET "


if [ "$NAME" != "" ]; then
  CMD=$CMD$ARG_NAME
fi

if [ "$TARGET" != "" ]; then
  HOST=$TARGET
  CMD=$CMD$ARG_TARGET
fi

$CMD

MAC_ADDRESS=$(grep 'net0:' /etc/pve/nodes/"$HOST"/qemu-server/"$NEW_VM_ID".conf | awk '{print $2}' | sed 's/virtio=\([^,]*\),bridge=.*/\1/')
echo "VM '$NEW_VM_ID' ('$NAME') MAC ADDRESS is '$MAC_ADDRESS'."
echo

pvesh create /nodes/"$TARGET"/qemu/"$NEW_VM_ID"/status/start

exit 0


