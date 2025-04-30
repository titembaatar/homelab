# 󰉋 Directory Structure

## ZFS Pool Vault
```
vault/
├── juerbiesu/ # Media storage
└── khulan/    # Database storage
```

## ZFS Pool Flash
```
flash/
├── yesugen/     # Config files storage
├── yesui/       # Docker compose files storage
└── moge_khatun/ # VM boot disks (handled by Proxmox)
```

## Borte - Backup NAS
```
borte/
├── proxmox-backups/ # VM backups (handled by Proxmox)
└── zfs/             # ZFS snapshots
    ├── daily/
    ├── weekly/
    ├── monthly/
    └── yearly/
```

## Juerbiesu (Media Storage)
Following TRaSH guide directory structure:
```
juerbiesu/
├── media/
│   ├── books/
│   │   ├── audiobooks/
│   │   └── ebooks/
│   ├── movies/
│   ├── music/
│   └── shows/
│       ├── anime/
│       └── tv/
├── torrents/
│   ├── books/
│   │   ├── audiobooks/
│   │   └── ebooks/
│   ├── movies/
│   ├── music/
│   │   └── slskd/
│   │       ├── downloads/
│   │       └── incomplete/
│   └── shows/
│       ├── anime/
│       └── tv/
└── usenet/
    ├── complete/
    │   ├── books/
    │   │   ├── audiobooks/
    │   │   └── ebooks/
    │   ├── movies/
    │   ├── music/
    │   └── shows/
    │       ├── anime/
    │       └── tv/
    └── incomplete/
```

Quick command for setup :
```bash
mkdir -p media/{books/{audiobooks,ebooks},movies,music,shows/{anime,tv}}
mkdir -p torrents/{books/{audiobooks,ebooks},movies,music/slskd/{downloads,incomplete},shows/{anime,tv}}
mkdir -p usenet/{incomplete,complete/{books/{audiobooks,ebooks},movies,music,shows/{anime,tv}}}
```

