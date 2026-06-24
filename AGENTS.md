# Fedora Niri Atomic

Personal Fedora atomic desktop image built with [bootc](https://bootc.dev/).

## Repository Purpose

This repo builds an OCI image (`ghcr.io/star122013/fedora-niri-atomic:latest`) based on Fedora Kinoite with:

- **niri** as the primary Wayland session
- parts of the **Hyprland** and **KDE/Plasma** ecosystem
- Chinese locale defaults (`Asia/Shanghai`, `zh_CN.UTF-8`)
- user customization from `config.toml`

## Current Build Layout

The repo no longer keeps all package/repo logic inline in `Containerfile`.
Instead it uses **Nu + NUON** under `build/`.

### Key files

- `Containerfile` — image build entrypoint; bootstraps `nushell`, copies `build/`, then runs the Nu build pipeline
- `build/config/repos.nuon` — repo definitions: rpmfusion, terra, COPRs, priority overrides
- `build/config/packages.nuon` — package groups, reinstall list, and remove list
- `build/config/extras.nuon` — extra RPM URLs and GitHub latest-release RPMs
- `build/config/system.nuon` — flatpak remotes and enabled systemd services
- `build/scripts/build.nu` — top-level orchestrator
- `build/scripts/lib/common.nu` — shared helpers
- `build/scripts/lib/repos.nu` — repo stage logic
- `build/scripts/lib/packages.nu` — package stage logic
- `build/scripts/lib/system.nu` — flatpak/font/service/bootc logic
- `build/README.md` — detailed build subsystem documentation
- `rootfs/` — files copied into the image with `COPY rootfs/ /`
- `config.toml` — user/timezone/locale customization

## Build Flow

`Containerfile` does roughly this:

1. bootstrap `rpmfusion`
2. enable `atim/nushell`
3. install `nushell`
4. `COPY build /tmp/build`
5. run:
   ```bash
   nu /tmp/build/scripts/build.nu /tmp/build
   ```

The Nu pipeline then runs three stages:

1. **repo stage** — rpmfusion / terra / rawhide disable / COPR / repo priority
2. **package stage** — install package groups / remove packages / extra RPMs
3. **system stage** — flatpak remotes / font cache / systemd services / `bootc container lint`

## Usage

### Inspect config

```bash
nu -c 'open build/config/repos.nuon | get copr.groups'
nu -c 'open build/config/packages.nuon | get groups.desktop'
```

### `reinstall` mechanism

When a package is pre-installed in the base image (e.g., `sway` from `fedora-sway-atomic`) and you want to replace it with a newer version from a COPR, add it to `reinstall` in `packages.nuon`. The pipeline will:

1. `dnf remove -y <package>` — uninstall the base image version
2. `dnf install -y <package>` — install from the highest-priority repo (your COPR)

This is needed because `dnf install` on an already-installed package is a no-op, even if a newer version is available in a COPR.

### Safe preview

Always prefer dry-run after config changes:

```bash
nu build/scripts/build.nu build --dry-run
```

With zmx:

```bash
zmx run system-oci -- nu build/scripts/build.nu build --dry-run
```

### Local image build

```bash
podman build -t fedora-niri-atomic:dev -f Containerfile .
```

## Agent Guidance

When modifying the build system:

- prefer editing `build/config/*.nuon` for data changes
- prefer editing `build/scripts/lib/*.nu` for logic changes
- keep `build/scripts/build.nu` thin; it should stay as orchestration only
- keep `Containerfile` focused on build entry/bootstrap, not large inline `dnf` logic
- run a dry-run after changing build config or build logic

## Important Constraints

- COPR repositories are critical; many packages come from them
- rawhide repos are explicitly disabled for stability
- bootstrap of `nushell` in `Containerfile` is intentional and required
- files under `/usr/lib/` are distro defaults, `/etc/` is mutable config, `/var/` is runtime state only

## CI

`.github/workflows/build.yml` builds and pushes on push, schedule, and manual dispatch.
