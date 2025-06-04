# ⚙️ Environment Variables & Secrets
## 📁 Configuration Structure
```
homelab/
├── docker/
│   ├── caddy/.env
│   ├── gateway/.env
│   ├── servarr/.env
│   ├── immich/.env
│   └── glance/.env
└── secrets/
    ├── cf-token
    ├── tinyauth
    ├── github-client
    ├── google-client
    ├── wireguard-private-key
    ├── immich-db-passwd
    ├── proxmox-token
    ├── github-token
    ├── immich-token
    ├── jellyfin-token
    ├── plex-token
    ├── tautulli-token
    ├── radarr-token
    ├── sonarr-token
    └── qbit-passwd
```

## 🔐 Secrets Management
### Generating Secrets
**Random Secret Generation:**
```bash
# Generate random 32-character secret
openssl rand -base64 32
```

**OAuth Setup:**
- **GitHub**: Go to Settings →  Developer settings →  OAuth Apps
- **Google**: Use Google Cloud Console →  APIs & Services →  Credentials

## 📋 Environment Variables by Service
### Global Variables
**`TZ`** - Timezone (used by all services)
```bash
TZ=Europe/Paris
```
**`DOMAIN`** - Domain name
```bash
DOMAIN=example.com
```

> [NOTE]
>
> All specific environment variables are in the docker compose files in case need to recover them.

## 🔍 Validation & Testing
### Verify Configuration
**Check environment variables are loaded:**
```bash
# Test with Docker Compose
docker compose config

# Check specific service environment
docker exec <container> env | grep -E "DOMAIN|TZ"
```

**Validate secrets are accessible:**
```bash
# Check secret file exists and has content
docker exec <container> cat /run/secrets/<secret-name>
```

**Test OAuth configuration:**
```bash
# Verify GitHub OAuth
curl -I "https://github.com/login/oauth/authorize?client_id=<your_client_id>"

# Verify Google OAuth
curl -I "https://accounts.google.com/oauth2/auth?client_id=<your_client_id>"
```

## ⚠️ Security Best Practices
### Secret Management
1. **Never commit secrets to Git:**
```bash
# Ensure .gitignore includes:
.env
*.env
secrets/
```

2. **Use strong, unique passwords:**
```bash
# Generate secure passwords
openssl rand -base64 32
```

3. **Limit OAuth scope permissions:**
   - GitHub: Only request necessary permissions
   - Google: Use minimal required scopes

### File Permissions
```bash
# Secure secrets directory
chmod 700 secrets/
chmod 600 secrets/*

# Secure environment files
chmod 600 docker/*/.env
```

