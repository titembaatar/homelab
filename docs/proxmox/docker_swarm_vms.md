# 🐳 Docker Swarm VM Setup Guide
Covers the creation of a standardized VM template and the subsequent cloning and configuration of the Docker Swarm manager and worker nodes.

## Base VM Template Creation
Creating a template ensures consistency across all Swarm nodes.

### Create the Initial VM
1.  **Access Proxmox Web UI:** Log into the web interface.
2.  **Click "Create VM"** (top right).
3.  **General Tab:**
    * **Node:** Select any node (e.g., `mukhulai`).
    * **VM ID:** Choose a high ID for the template (e.g., `9000`).
    * **Name:** `swarm-template`
4.  **OS Tab:**
    * Select Debian ISO.
    * **Guest OS Type:** `Linux`
    * **Version:** Select the appropriate kernel version (e.g., 6.x).
5.  **System Tab:**
    * **Graphic card:** `Default`
    * **Machine:** `q35`
    * **BIOS:** `OVMF (UEFI)`
    * **Add EFI Disk:** Check the box, select `local`
    * **SCSI Controller:** `VirtIO SCSI single`
    * **Qemu Agent:** Check the box (Install agent later in the OS).
6.  **Disks Tab:**
    * **Bus/Device:** `VirtIO Block` (or `SCSI` if preferred).
    * **Storage:** `local` (or your local VM storage).
    * **Disk size (GiB):** `32`.
    * **SSD emulation:** Check if using SSD storage.
7.  **CPU Tab:**
    * **Cores:** `2` (Template default, can be adjusted per VM later).
    * **Type:** `host` (Generally recommended for best performance if not migrating between different CPU types).
8.  **Memory Tab:**
    * **Memory (MiB):** `2048` (Template default, adjust per VM later).
9.  **Network Tab:**
    * **Bridge:** `vmbr0`
    * **Model:** `VirtIO (paravirtualized)`
    * **Firewall:** Unchecked (or configure as needed).
    * *(Leave MAC address blank - Proxmox will generate one).*
10. **Confirm Tab:** Review and click `Finish`.

### Install Debian OS
1. **Start the VM:** Select the created VM (ID 9000) and click `Start`. Open the `Console`.
2. **Follow Debian Installer:**
    * Choose language, location, keyboard.
    * **Network:** Configure network. Set a temporary hostname like `debian-template`. Domain name can be left blank or set to `your.domain.lan`.
    * **Users:** Set a root password. Create a standard user (e.g., `titem`) and password.
    * **Partitioning:** Use guided - use entire disk. Select the VirtIO disk. Choose a partitioning scheme (separate /home is optional). Finish partitioning.
    * **Software Selection:** Select only **"SSH server"** and **"standard system utilities"**.
    * **GRUB:** Install GRUB boot loader to the primary drive (`/dev/vda` or `/dev/sda`).
    * Finish installation and reboot.

### Configure Base System & Install Tools
1. **Login:** Start the VM console or SSH into the VM using the user created during install (e.g., `titem`). Use `su - root` and add user to sudo group: `usermod -aG sudo titem`.
2. **Install Essential Tools:**
    ```bash
    sudo apt update
    sudo apt install -y sudo
    ```
3. **Run [env script](../../scripts/env/setup.sh)**
4. **Enable Qemu Guest Agent:**
    ```bash
    sudo systemctl enable --now qemu-guest-agent
    ```
    *(Shutdown the VM from inside the OS (`sudo shutdown now`), then check the VM Summary page in Proxmox - you should see the IP address listed if the agent is working).*

### Install Docker Engine
```bash
# Add Docker's official GPG key:
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker titem
docker --version
```

### Final Template Cleanup
1. **Clean Apt Cache:**
    ```bash
    sudo apt clean
    sudo rm -rf /var/lib/apt/lists/*
    ```
2. **Clear Bash History:**
    ```bash
    truncate -s 0 ~/.bash_history
    rm ~/.bash_history
    # Repeat for root
    ```
3. **Reset Machine ID (Optional but Recommended):** Ensures cloned VMs get unique IDs.
    ```bash
    sudo truncate -s 0 /etc/machine-id
    sudo rm /var/lib/dbus/machine-id
    sudo ln -s /etc/machine-id /var/lib/dbus/machine-id
    ```
4. **Shutdown the VM:**
    ```bash
    sudo shutdown now
    ```

### Convert to Template
1. **Wait for VM to stop.**
2. **Right-click** the VM (ID 9000) in the Proxmox UI.
3. Select **"Convert to template"**.

## Clone Swarm Node VMs
Now, clone the template to create your manager and worker nodes.

### Define Resources
Plan the resources for each type of node:

* **Managers (`subeedei`, `zev`, `khubilai`):**
    * vCPUs: `2`
    * RAM: `2048` MiB (2 GB)
    * Disk: `32` GiB
* **Workers (`uriankhai`, `besud`, `baarin`):**
    * vCPUs: `2` *(Adjust based on expected workload, start low)*
    * RAM: `4096` MiB (4 GB) *(Adjust based on expected workload)*
    * Disk: `32` GiB

### Clone Manager VMs
Repeat these steps three times for managers:
1. **Right-click** the template (ID 9000).
2. Select **"Clone"**.
3. **Mode:** `Full Clone`
4. **Target Node:** Choose a Proxmox host (distribute them, e.g., `subeedei` on `mukhulai`, `zev` on `borchi`, `khubilai` on `borokhul`).
5. **VM ID:** Assign unique IDs (e.g., `120`, `121`, `122`).
6. **Name:** Set the correct hostname (e.g., `subeedei`, `zev`, `khubilai`).
7. **Storage:** Select `moge_khatun`.
8. Click **"Clone"**.
9. **After Cloning:**
    * Select the newly cloned VM.
    * Go to **Hardware**.
    * Adjust **CPU cores** and **Memory** to match the defined resources (e.g., 2 cores, 2048 MiB RAM for managers).
    * *(Disk size was set during template creation/clone).*
    * *(Network device MAC will be unique, ensure it's set to use `vmbr0` and DHCP).*

### Clone Worker VMs
Repeat these steps three times for workers:
1. **Right-click** the template (ID 9000).
2. Select **"Clone"**.
3. **Mode:** `Full Clone`
4. **Target Node:** Choose a Proxmox host (distribute them).
5. **VM ID:** Assign unique IDs (e.g., `130`, `131`, `132`).
6. **Name:** Set the correct hostname (e.g., `uriankhai`, `besud`, `baarin`).
7. **Storage:** Select `moge_khatun`.
8. Click **"Clone"**.
9. **After Cloning:**
    * Select the newly cloned VM.
    * Go to **Hardware**.
    * Adjust **CPU cores** and **Memory** to match the defined resources (e.g., 2 cores, 4096 MiB RAM for workers).

## Initial VM Boot & Verification
1.  **Start all 6 cloned VMs.**
2.  **Verify IP Addresses:** Check the VM Summary page in Proxmox or log into the Freebox Pro DHCP reservations list to confirm each VM received its correct reserved IP address.
3.  **Verify Hostnames:**
    * SSH into each VM (using its reserved IP).
    * Run `hostname`. It should match the name given during cloning (e.g., `subeedei`). If not (e.g., it still says `debian-template`), update it:
        ```bash
        sudo hostnamectl set-hostname subeedei # Replace with correct name
        # Also update /etc/hosts if needed
        sudo nvim /etc/hosts # Ensure 127.0.1.1 maps to the correct hostname
        ```
4.  **Verify Docker:** Run `docker --version` or `sudo docker --version` to ensure Docker is installed and running.
5.  **Verify NFS Client:** Run `showmount -e 10.0.0.10` (from any Swarm VM) to check if they can see the NFS exports from `mukhulai`.

Your Swarm node VMs are now provisioned and ready for the Docker Swarm initialization steps.
