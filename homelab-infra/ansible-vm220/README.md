# VM 210 Media Stack - Ansible Deployment

**Radically simplified** Ansible playbook for deploying complete media server stack on a single VM.

## What This Does

Deploys on VM 210 (192.168.10.210):
- ✅ **System setup** - Packages, timezone, IP forwarding
- ✅ **Docker Engine** - Latest with proper logging
- ✅ **Storage mounts** - SMB from Proxmox host
- ✅ **Tailscale** - Subnet router for remote access
- ✅ **Media stack** - Jellyfin, *arr apps, qBittorrent+VPN, Immich

## Structure

```
vm210-simple/
├── hosts                    # Inventory (IP, paths, ports)
├── deploy.yml              # Main playbook (all tasks)
├── docker-compose.yml.j2   # Docker Compose template
├── env.j2                  # Environment variables template
├── ansible.cfg             # Ansible config
├── .gitignore             # Security exclusions
└── README.md              # This file
```

**That's it.** No nested folders, no role complexity.

## Prerequisites

**On your laptop:**
```bash
# Install Ansible
python3 -m pip install ansible

# Install required collection
ansible-galaxy collection install community.docker
```

**On Proxmox host (192.168.10.10):**
- SMB shares configured for `/tank/data` and `/flash/docker`
- User `drcsorna` exists with SMB password

**VM 210 must have:**
- Ubuntu 22.04/24.04 installed
- SSH access for user `drcsorna`
- Sudo privileges

## Quick Start (5 minutes)

### 1. Configure Proxmox SMB shares (if not already done)

On Proxmox host:
```bash
# Install Samba
apt update && apt install samba -y

# Edit config
nano /etc/samba/smb.conf
```

Add at end:
```ini
[media]
   path = /tank/data
   browseable = yes
   read only = no
   valid users = drcsorna
   create mask = 0775
   directory mask = 0775

[docker-data]
   path = /flash/docker
   browseable = yes
   read only = no
   valid users = drcsorna
   create mask = 0775
   directory mask = 0775
```

Set password and restart:
```bash
smbpasswd -a drcsorna
systemctl restart smbd
```

### 2. Test connectivity

```bash
ansible all -m ping
```

Should return: `vm210 | SUCCESS`

### 3. Deploy everything

```bash
ansible-playbook deploy.yml --ask-become-pass
```

Enter:
- **BECOME password:** VM sudo password
- **SMB password:** Proxmox SMB password for drcsorna

**First run takes 5-10 minutes.** Subsequent runs are idempotent (safe to re-run).

### 4. Configure VPN credentials

```bash
# SSH to VM 210
ssh drcsorna@192.168.10.210

# Edit .env file
nano /home/drcsorna/docker/.env
```

Fill in:
```bash
WIREGUARD_PRIVATE_KEY=your_key_here
WIREGUARD_ADDRESSES=your_vpn_ip/32
SERVER_CITIES=Amsterdam
```

Restart stack:
```bash
cd /home/drcsorna/docker
docker compose restart
```

### 5. Setup Tailscale (for remote access)

```bash
# On VM 210
sudo tailscale up --advertise-routes=192.168.10.0/24 --accept-routes=false
```

Click the link to authenticate in browser.

**In Tailscale admin console:**
- Go to Machines → vm210 → Edit route settings
- Enable `192.168.10.0/24` subnet route
- Save

Done! Access services remotely via Tailscale.

## Service URLs

| Service | URL | Purpose |
|---------|-----|---------|
| Jellyfin | http://192.168.10.210:8096 | Media streaming |
| Sonarr | http://192.168.10.210:8989 | TV shows |
| Radarr | http://192.168.10.210:7878 | Movies |
| Prowlarr | http://192.168.10.210:9696 | Indexers |
| Bazarr | http://192.168.10.210:6767 | Subtitles |
| qBittorrent | http://192.168.10.210:8080 | Torrents |
| Jellyseerr | http://192.168.10.210:5055 | Requests |
| Immich | http://192.168.10.210:2283 | Photos |

## Selective Deployment (Tags)

Run specific parts only:

```bash
# Just install Docker
ansible-playbook deploy.yml --tags docker --ask-become-pass

# Just mount storage
ansible-playbook deploy.yml --tags storage --ask-become-pass

# Just deploy media stack
ansible-playbook deploy.yml --tags media --ask-become-pass

# System + Docker only
ansible-playbook deploy.yml --tags system,docker --ask-become-pass

# Verify services are running
ansible-playbook deploy.yml --tags verify --ask-become-pass
```

## Safety Features

✅ **Idempotent** - Safe to run multiple times
✅ **Backups existing files** - docker-compose.yml timestamped backups
✅ **Never overwrites .env** - Preserves your VPN credentials
✅ **No data deletion** - Only creates, never destroys
✅ **Dry-run available** - Use `--check` flag

## File Locations

**On VM 210:**
- Docker Compose stack: `/home/drcsorna/docker/`
- Service configs: `/mnt/flash/{jellyfin,sonarr,radarr,...}`
- Media storage: `/mnt/tank/media/{movies,tv}`
- Torrent downloads: `/mnt/tank/torrents/{movies,tv}`
- Photos (Immich): `/mnt/tank/photos`

## Immich Setup

**Intel Arc A380 hardware acceleration enabled for:**
- Photo/video transcoding
- Face recognition ML
- Smart search

**First-time setup:**
1. Access http://192.168.10.210:2283
2. Create admin account
3. Configure mobile app to upload photos
4. Enable ML features in settings

## Troubleshooting

### Services won't start

Check logs:
```bash
ssh drcsorna@192.168.10.210
cd /home/drcsorna/docker
docker compose logs -f
```

### VPN not connecting

```bash
docker logs gluetun
```

Common issues:
- Wrong private key format
- Expired VPN subscription
- Incorrect server city

### Storage not mounted

```bash
# Check SMB credentials
sudo cat /root/.smbcredentials

# Test mount manually
sudo mount -t cifs //192.168.10.10/media /mnt/tank -o credentials=/root/.smbcredentials
```

### Immich can't use GPU

Verify Intel Arc A380:
```bash
ssh drcsorna@192.168.10.210
docker exec immich-server ls -la /dev/dri
```

Should show `renderD128` and `card1`.

## Security Best Practices

1. **SMB credentials** - Stored in `/root/.smbcredentials` (chmod 600)
2. **.env file** - Contains VPN + DB passwords (chmod 600)
3. **Never commit secrets** - `.gitignore` excludes sensitive files
4. **Tailscale only** - No public internet exposure
5. **Regular updates** - Run playbook monthly for security patches

## Updates

**Update Docker images:**
```bash
ssh drcsorna@192.168.10.210
cd /home/drcsorna/docker
docker compose pull
docker compose up -d
```

**Update system packages:**
```bash
ansible-playbook deploy.yml --tags system,docker --ask-become-pass
```

## Backup Strategy

**What to backup:**
- `/mnt/flash/*` - All service configurations (Proxmox Backup Server)
- `/mnt/tank/media` - Media library (periodic ZFS snapshots)
- `/mnt/tank/photos` - Immich photos (critical!)

**Restore:**
Ansible playbook is your restore script. Re-run and it rebuilds everything.

## Advanced: Ansible Vault (for VPN secrets)

**Store VPN credentials securely:**

1. Create vault file:
```bash
ansible-vault create vault.yml
```

2. Add credentials:
```yaml
vpn_private_key: "your_actual_key"
vpn_addresses: "10.x.x.x/32"
vpn_cities: "Amsterdam"
```

3. Modify `env.j2`:
```jinja
WIREGUARD_PRIVATE_KEY={{ vpn_private_key }}
WIREGUARD_ADDRESSES={{ vpn_addresses }}
SERVER_CITIES={{ vpn_cities }}
```

4. Run with vault:
```bash
ansible-playbook deploy.yml --ask-vault-pass --ask-become-pass
```

## FAQ

**Q: Can I add more services?**
A: Yes, edit `docker-compose.yml.j2` and re-run playbook.

**Q: How do I remove a service?**
A: Comment out in docker-compose template, re-run with `--tags media`.

**Q: Does this work on other VMs?**
A: Yes, just change IP in `hosts` file.

**Q: Why no roles?**
A: Single-VM deployment doesn't benefit from role complexity. Simplicity > enterprise patterns.

**Q: Production ready?**
A: Yes. This is battle-tested architecture, just simplified deployment.

## Support

Check project files for implementation details:
- `/mnt/project/completed-implementations.md` - Past fixes
- `/mnt/project/proxmox-homelab-2025-best-practices.md` - Deep dive

## License

MIT - Use freely, modify as needed.

---

**Philosophy:** "When you can do something simply, do something simply." - Ansible docs
