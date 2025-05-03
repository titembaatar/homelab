# 🔑 Secrets Management Strategy

## Philosophy
Handling sensitive information (secrets) like API keys, passwords, tokens, and credentials securely is paramount to the overall security of the homelab. The core principles are:
1.  **Minimize Exposure:** Secrets should never be hardcoded in applications, committed to Git repositories, or stored insecurely in configuration files or environment variables.
2.  **Centralized Management:** Use dedicated tools for storing and managing secrets.
3.  **Secure Injection:** Use the orchestration platform's native secrets mechanism to inject secrets into containers only when and where needed.

## Primary Mechanism: Docker Swarm Secrets
* **How:** Docker Swarm's built-in **Secrets** feature is the standard method for managing sensitive data required by services running in the cluster.
* **Creation:** Secrets are typically created using the `docker secret create <secret-name> <file-containing-secret>` command or by defining them in the top-level `secrets:` section of a stack file (often referencing `external: true` if created manually beforehand).
* **Storage:** Docker Swarm stores secrets encrypted in its internal Raft database, which is replicated across manager nodes for resilience.
* **Injection:** Secrets are mounted into authorized containers as read-only files within the `/run/secrets/` directory. Applications need to be configured to read secrets from these files.
* **Benefits:** Provides secure storage at rest (within Swarm), secure distribution to nodes, and controlled access only for services granted permission.

## Authoritative Source & Master Copies
* While Docker Swarm manages the *injection* of secrets into containers, it's not the ideal place to store the *original* or *master copy* of a secret, especially for recovery purposes.
* **Recommendation:** A dedicated **Password Manager** (such as Bitwarden/Vaultwarden, KeePassXC, 1Password, etc.) should be used as the central, secure vault and authoritative source for:
    * Generating strong, unique passwords.
    * Storing externally generated API keys and tokens (Cloudflare API Token, Tunnel Token, Notifiarr keys, application passwords, TinyAuth user password hashes/secrets, etc.).
    * Storing the master encryption key for any encrypted backups.

## Typical Workflow
1.  **Generate/Obtain Secret:** Create a new password or receive an API key.
2.  **Store Master Copy:** Securely store this original secret in the designated Password Manager, along with notes about its purpose (e.g., "Cloudflare API Token for Homelab DNS").
3.  **Create Docker Secret:** Use the value from the password manager to create the Docker Secret via `docker secret create`.
4.  **Reference in Stack:** Grant access to the secret in the service definition within your `docker-compose.yml` stack file.
5.  **Application Config:** Configure the application inside the container to read the secret from its mount path (e.g., `/run/secrets/cloudflare_api_token`).

## Handling `.env` Files
* As a strict policy, **`.env` files MUST NOT contain secrets.**
* They should only be used for non-sensitive configuration or variable substitution within compose files (e.g., `TZ`, `PUID`, `PGID`, image tags).
* `.env` files should generally remain in `.gitignore`. Use `.env.example` files checked into Git to document required variables without exposing values.
