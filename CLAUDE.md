# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Fedora bootc-based atomic desktop image. It builds an OCI container image installable as a bootable atomic system via `ostreecontainer`. The image provides **both** KDE Plasma (from fedora-kinoite) **and** niri (independent Wayland WM) as selectable sessions via SDDM.

## Key Files

- **Containerfile** — OCI image definition for the bootc system container. Base: `fedora-kinoite:43`
- **basic.cfg** — Anaconda kickstart file for automated installation from the container image
- **config.toml** — osbuild configuration (user customization template for `fedora-bootc-install`)
- **rootfs/** — Overlay filesystem structure:
  - `rootfs/usr/tmpfiles.d/bootc-var-dirs.conf` — Declares /var directories created during build (required by bootc container lint)
  - `rootfs/usr/systemd/system/sddm.service.d/boot-order.conf` — SDDM ordering requirements
  - `rootfs/etc/locale.conf` — System locale configuration

## Build Commands

```bash
# Build the container image locally
docker build -f Containerfile -t ghcr.io/star122013/fedora-niri-atomic:latest .

# Push to ghcr.io (requires docker login)
docker push ghcr.io/star122013/fedora-niri-atomic:latest

# Validate Containerfile with bootc lint
bootc container lint
```

## Architecture Notes

- **bootc** — Project that converts Containerfiles into bootable OS images. Uses ostree under the hood.
- **ostreecontainer** — Kickstart directive to install a running system from an OCI image. The `basic.cfg` uses this to install the built image.
- **niri** — Independent Wayland WM (not KDE-based). Installed via COPR (`yalter/niri-git`). Both KDE Plasma and niri sessions are available via SDDM.
- **File placement rules for bootc**:
  - `/usr/lib/` — read-only distro defaults (modprobe.d, dracut, systemd, sddm)
  - `/etc/` — mutable admin config
  - `/var/` — runtime state only; never ship files here; use tmpfiles.d

## Version Control

This repository uses **Jujutsu (jj)** as the primary VCS, with git interoperability. The `.jj/` directory contains the jj repo state. Git operations work through jj's git compatibility layer.
