# Fedora Niri Atomic

Personal Fedora atomic desktop image built with [bootc](https://bootc.dev/).

## Repository Purpose

This repo builds an OCI image (`ghcr.io/star122013/fedora-niri-atomic:latest`) containing a Fedora Kinoite (KDE Plasma 6) desktop with:
- **niri** (wayland compositor) as primary session
- **Hyprland** and **Plasma 6** also available
- Chinese locale defaults (`Asia/Shanghai`, `zh_CN.UTF-8`)
- User: `cyrene` (wheel group, password `cyrene`)

## Key Files

- `Containerfile` — multi-stage build; stages 0-1 download fonts/grub theme, stage 2 is the final system
- `basic.cfg` — Kickstart file for installing the image via Anaconda
- `rootfs/` — Files copied into the container at build time (`COPY rootfs/ /`)
- `config.toml` — System timezone/locale/user customization (used by Image Builder or similar)

## Build & Deploy

```bash
# Local build (requires podman/buildah with bootc support)
podman build -t ghcr.io/star122013/fedora-niri-atomic:latest -f Containerfile .

# Validate Containerfile
bootc container lint

# Push to ghcr.io (done automatically via .github/workflows/build.yml on push + daily)
podman push ghcr.io/star122013/fedora-niri-atomic:latest
```

## CI

`.github/workflows/build.yml` builds and pushes on every push and daily at midnight UTC. No manual test step — `bootc container lint` in the Containerfile provides validation.

## Tooling

- **VCS**: Jujutsu (`.jj/`), not git (`.git/` exists but is secondary)
- **Package manager**: Pixi (`.pixi/`), mise (`mise.toml`)

## Special Considerations

- COPR repositories are critical — many packages (niri-git, hyprland, starship, etc.) come from COPRs enabled in the Containerfile
- Rawhide repos are explicitly disabled to avoid stability issues
- Files under `/usr/lib/` are distro defaults; `/etc/` is mutable admin config; `/var/` is runtime state only (bootc philosophy)
