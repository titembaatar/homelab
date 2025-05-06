#!/bin/bash
set -e

sudo mkdir -p /mnt/juerbiesu /mnt/khulan /mnt/yesugen /mnt/yesui

sudo cp /etc/fstab /etc/fstab.bak

sudo tee -a /etc/fstab << EOF
# NFS
10.0.0.10:/vault/juerbiesu  /mnt/juerbiesu/ nfs    rw,defaults,soft,_netdev,noatime,nodiratime 0 0
10.0.0.10:/vault/khulan     /mnt/khulan/    nfs    rw,defaults,soft,_netdev,noatime,nodiratime 0 0
10.0.0.10:/flash/yesugen    /mnt/yesugen/   nfs    rw,defaults,soft,_netdev,noatime,nodiratime 0 0
10.0.0.10:/flash/yesui      /mnt/yesui/     nfs    rw,defaults,soft,_netdev,noatime,nodiratime 0 0
EOF

sudo systemctl daemon-reload
sudo mount -a

sudo ls -l /mnt
