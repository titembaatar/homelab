# 🛠️ Update & Maintenance Philosophy

## Overall Approach
The primary goal of maintenance in this homelab is to ensure **stability and security**.
Updates are performed manually and selectively, following an "if it works, don't fix it" principle,
with exceptions primarily for security vulnerabilities or highly desired new features.
Chasing the absolute latest versions is not a goal.

Downtime during planned maintenance windows is acceptable.

## Update Procedures
Updates are handled manually via SSH and command-line tools. GUIs are generally avoided for system administration tasks.

1.  **Proxmox VE Hosts (`Mukhulai`, `Borchi`, `Borokhul`):**
    * **Method:** Connect via SSH and run `apt update && apt dist-upgrade`. Review proposed changes before confirming.
    * **Frequency:** Ad-hoc, based on manual checks (e.g., quarterly, or when specific PVE features/fixes are needed). Security updates from Debian/Proxmox repositories are prioritized if critical vulnerabilities are announced.

2.  **Swarm Node VMs (OS - Debian):**
    * **Method:** Connect via SSH to each Swarm manager and worker VM and run `apt update && apt upgrade`. Review changes.
    * **Frequency:** Ad-hoc, typically performed alongside host updates or when critical OS-level security patches are released.

3.  **Docker Engine (on Swarm Node VMs):**
    * **Method:** Updated via `apt` as part of the VM OS update process.
    * **Frequency:** Updated along with the VM OS.

4.  **Docker Container Images:**
    * **Strategy:** Container images are defined in Docker stack files using **specific version tags**, not `:latest`. This ensures predictable deployments.
    * **Update Trigger:** Updates are **not** automatic. An image is only updated if:
        * A significant security vulnerability is discovered in the specific version being used.
        * A new version introduces a specific feature or bug fix that is actively desired.
    * **Update Process:**
        1. Manually check the relevant project's GitHub releases, changelogs, or security advisories.
        2. Decide if an update is warranted based on the triggers above.
        3. Manually edit the image tag in the corresponding `docker-compose.yml` stack file (located on `flash/yesui`).
        4. Commit the change to Git.
        5. Re-deploy the stack using `docker stack deploy -c /path/to/docker-compose.yml <stack_name>`. Swarm will perform a rolling update based on the service's `update_config` (if defined).
    * **Tools Avoided:** No automated update tools or notification tools are used, adhering to the manual control philosophy.

5.  **Application Configurations:**
    * **Method:** Configurations stored on NFS/ZFS (`flash/yesugen`) are edited manually.
    * **Tracking:** Changes to stack files (`flash/yesui`) are tracked via Git. ZFS snapshots provide point-in-time recovery for config datasets *(See [Backup Strategy](./backup.md))*.

## Monitoring for Updates
* Staying informed about available updates relies on **manually** checking sources for software used in the homelab:
    * Following relevant projects on GitHub (checking Releases/Tags).
    * Monitoring security feeds or news sites for critical vulnerability announcements.
    * Occasionally checking Proxmox / Debian / Docker documentation for major release changes.

## Rollback Strategy
* **Containers:** If an updated container image causes issues, the primary rollback method is to edit the stack file back to the previous known-good image tag and re-deploy the stack.
* **OS/PVE:** Before significant OS or Proxmox upgrades, ZFS snapshots of the root filesystem (if configured) or Proxmox VM backups *(See [Backup Strategy](./backup.md))* can provide rollback points. Configuration changes are tracked in Git.

