# 🖥️ Debian Bare-Metal VM Template Guide
This document covers the creation of a standardized Debian 12 VM template suitable for running applications directly on the operating system (non-containerized), 
such as media servers or other specific workloads.

## Base VM Template Creation

### Create the Initial VM

1.  **Access Proxmox Web UI:** Log into the web interface.
2.  **Click "Create VM"** (top right).
3.  **General Tab:**
    * **Node:** Select any node (e.g., `mukhulai`).
    * **VM ID:** Choose a high ID for the template (e.g., `9001`).
    * **Name:** `debian-template`
4.  **OS Tab:**
    * **Use CD/DVD disc image file (iso):** Select the Debian ISO.
    * **Guest OS Type:** `Linux`
    * **Version:** Select the appropriate kernel version (e.g., 6.x).
5.  **System Tab:**
    * **Graphic card:** `Default`
    * **Machine:** `q35`
    * **BIOS:** `OVMF (UEFI)`
    * **Add EFI Disk:** Check the box, select `local`.
    * **SCSI Controller:** `VirtIO SCSI single`
    * **Qemu Agent:** Check the box (Install agent later in the OS).
6.  **Disks Tab:**
    * **Bus/Device:** `VirtIO Block` (or `SCSI`).
    * **Storage:** `local` (or your local VM storage).
    * **Disk size (GiB):** `16` (Adjust as needed for your base template - applications might need more space than Swarm nodes).
    * **SSD emulation:** Check if using SSD storage.
7.  **CPU Tab:**
    * **Cores:** `2` (Template default, adjust per VM later).
    * **Type:** `host`.
8.  **Memory Tab:**
    * **Memory (MiB):** `2048` (Template default, adjust per VM later - Plex/Jellyfin often benefit from more RAM, e.g., 4096+).
9.  **Network Tab:**
    * **Bridge:** `vmbr0` (or your main VM bridge).
    * **Model:** `VirtIO (paravirtualized)`
    * **Firewall:** Unchecked (or configure as needed).
    * *(Leave MAC address blank - Proxmox will generate one).*
10. **Confirm Tab:** Review and click `Finish`.

### Install Debian OS
1.  **Start the VM:** Select the created VM (ID 9001) and click `Start`. Open the `Console`.
2.  **Follow Debian Installer:**
    * Choose language (e.g., English), location (e.g., France), keyboard (e.g., French). Select a default locale when prompted (e.g., `en_US.UTF-8`).
    * **Network:** Configure network (should get IP via DHCP). Set hostname `debian-baremetal-template`. Domain name `your.domain.lan`.
    * **Users:** Set a root password. Create a standard user (e.g., `titem`) and password.
    * **Partitioning:** Use guided - use entire disk. Select the VirtIO disk. Choose a partitioning scheme. Finish partitioning.
    * **Software Selection:** Deselect Desktop Environment and Print Server. Select only **"SSH server"** and **"standard system utilities"**.
    * **GRUB:** Install GRUB boot loader to the primary drive.
    * Finish installation and reboot. Remove the ISO from the virtual CD drive afterwards.

### Configure Base System & Install Tools
1.  **Login:** Start the VM console or SSH into the VM using the user created during install (e.g., `titem`). Use `su -` or `sudo` (`usermod -aG sudo titem` if needed).
2. **Run [env script](../../scripts/env/setup.sh)**
3.  **Enable Qemu Guest Agent:**
    ```bash
    systemctl enable --now qemu-guest-agent
    ```
    *(Shutdown (`sudo shutdown now`) and verify IP appears in Proxmox Summary after restart).*

### e. Configure Direct Storage Mounts (Optional but common for Media Servers)

If VMs cloned from this template will need direct access to your NFS/SMB media shares (e.g., Plex/Jellyfin libraries), configure the mounts within the template. **Using NFS is generally recommended for Linux VMs.**

1.  **Create Mount Points:**
    ```bash
    mkdir -p /mnt/juerbiesu/ /mnt/khulan/ /mnt/yesugen/ /mnt/yesui/
    ```
2.  **Configure `/etc/fstab`:** Add entries to automatically mount the shares on boot.
    ```bash
    sudo nvim /etc/fstab
    ```
    *Add NFS entries (replace IP and paths as needed):*
    ```fstab
    # NFS
    10.0.0.10:/vault/juerbiesu  /mnt/juerbiesu/ nfs    rw,defaults,soft,_netdev,noatime,nodiratime 0 0
    10.0.0.10:/vault/khulan     /mnt/khulan/    nfs    rw,defaults,soft,_netdev,noatime,nodiratime 0 0
    10.0.0.10:/flash/yesugen    /mnt/yesugen/   nfs    rw,defaults,soft,_netdev,noatime,nodiratime 0 0
    10.0.0.10:/flash/yesui      /mnt/yesui/     nfs    rw,defaults,soft,_netdev,noatime,nodiratime 0 0
    ```
3.  **Test Mounts:**
    ```bash
    systemctl daemon-reload
    sudo mount -a
    ls -l /mnt
    ```

### Final Template Cleanup
1.  **Clean Apt Cache:**
    ```bash
    sudo apt clean
    sudo rm -rf /var/lib/apt/lists/*
    ```
2.  **Clear Bash History:**
    ```bash
    truncate -s 0 ~/.bash_history
    rm ~/.bash_history
    # Repeat for root user if necessary
    ```
3.  **Reset Machine ID (Recommended):**
    ```bash
    sudo truncate -s 0 /etc/machine-id
    sudo rm /var/lib/dbus/machine-id
    sudo ln -s /etc/machine-id /var/lib/dbus/machine-id
    ```
4.  **Shutdown the VM:**
    ```bash
    sudo shutdown now
    ```

### Convert to Template
1.  **Wait for VM to stop.**
2.  **Right-click** the VM (ID 9001) in the Proxmox UI.
3.  Select **"Convert to template"**.

## Cloning VMs from Template
When creating a new VM for Plex, Jellyfin, or another bare-metal application:

1.  **Right-click** the `debian-template`.
2.  Select **"Clone"**.
3.  Choose **Full Clone**, target node, set a unique **VM ID** and **Name** (e.g., `plex-server`).
4.  Select the appropriate **Storage** (e.g., `local`).
5.  After cloning, **adjust resources** (CPU, Memory) as needed for the specific application.
6.  Boot the VM, verify its IP address (obtained via DHCP reservation), and ensure storage mounts (if configured in the template) are working.
7.  Proceed with installing the specific application (Plex, Jellyfin, etc.) according to its own documentation.

### Post cloning
Change hostname in `/etc/hostname` and `/etc/hosts`
Run :
```bash
sudo hostnamectl set-hostname new-vm-hostname
hostname
```
