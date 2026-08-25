# fedora-niri-atomic

> Chinese version: [README-zh.md](README-zh.md)

A personal Fedora Atomic desktop image repository built on [bootc](https://bootc.dev/).

The current goals are roughly:

- base the image on `quay.io/fedora/fedora-kinoite:44`
- provide a usable Wayland desktop environment
- keep parts of the Hyprland / KDE ecosystem available
- manage repos, packages, and system configuration with `Containerfile + Nu + NUON`

---

## Repository layout

```text
.
├── README.md                     # repository overview and usage (English)
├── README-zh.md                  # repository overview and usage (Chinese)
├── AGENTS.md                     # instructions for coding agents / automation tools
├── Containerfile                 # OCI / bootc image build entrypoint
├── config.toml                   # user, timezone, locale, and related customization
├── mise.toml                     # local toolchain management
├── .github/
│   └── workflows/
│       └── build.yml             # GitHub Actions workflow for build and push
├── build/
│   ├── README.md                 # build subsystem documentation (English)
│   ├── README-zh.md              # build subsystem documentation (Chinese)
│   ├── config/
│   │   ├── repos.nuon            # repo config: rpmfusion / terra / copr / priority
│   │   ├── packages.nuon         # package groups and remove list
│   │   ├── extras.nuon           # extra RPMs / GitHub latest release entries
│   │   └── system.nuon           # flatpak remotes / systemd services
│   └── scripts/
│       ├── build.nu              # top-level Nu entrypoint
│       └── lib/
│           ├── common.nu         # shared helpers
│           ├── repos.nu          # repo stage logic
│           ├── packages.nu       # package stage logic
│           └── system.nu         # system stage logic
└── rootfs/                       # files copied directly into the image filesystem
    ├── etc/
    └── usr/
```

---

## What each part is responsible for

### `Containerfile`
Responsible for:

- defining the multi-stage image build
- downloading font assets
- bootstrapping `nushell`
- invoking `build/scripts/build.nu`
- producing the final bootc/OCI image

It now acts mainly as a thin orchestration entrypoint instead of holding a very long inline `RUN dnf ...` chain.

---

### `build/`
Responsible for the config-driven build system:

- `NUON` files describe **what** to install or enable
- `Nu` scripts describe **how** to execute the build steps

See also:

- [`build/README.md`](build/README.md)
- [`build/README-zh.md`](build/README-zh.md)

---

### `rootfs/`
Responsible for static filesystem content copied into the image:

- systemd configuration
- environment files
- application configuration
- anything else that should be shipped via `COPY rootfs/ /`

If something is fundamentally “filesystem content inside the image”, it should usually live here rather than be generated dynamically by a script.

---

### `config.toml`
Responsible for system customization such as:

- user
- timezone
- locale
- keyboard layout

Current values include:

- user `cyrene`
- timezone `Asia/Shanghai`
- language `zh_CN.UTF-8`

---

### `.github/workflows/build.yml`
Responsible for CI:

- build on push
- scheduled build
- manual dispatch
- push image to `ghcr.io/star122013/fedora-niri-atomic:latest`

---

## Build subsystem layout

```text
build/
├── config/
│   ├── repos.nuon
│   ├── packages.nuon
│   ├── extras.nuon
│   └── system.nuon
└── scripts/
    ├── build.nu
    └── lib/
        ├── common.nu
        ├── repos.nu
        ├── packages.nu
        └── system.nu
```

Responsibilities:

- `repos.nuon`: repo sources and priorities
- `packages.nuon`: package groups and removal list
- `extras.nuon`: extra RPMs and GitHub latest-release logic
- `system.nuon`: flatpak and service configuration
- `build.nu`: top-level orchestration
- `lib/*.nu`: logic split by stage to keep files manageable

---

## Usage

### 1. Preview the build plan first

After changing `build/config/*.nuon`, run a dry-run first:

```bash
nu build/scripts/build.nu build --dry-run
```

Short form:

```bash
nu build/scripts/build.nu build -n
```

This prints:

- which repos will be enabled
- which packages will be installed
- which packages will be removed
- which flatpak remotes will be added
- which systemd services will be enabled

It does **not** actually run `dnf`, `systemctl`, or `bootc`.

---

### 2. Build the image locally

```bash
podman build -t ghcr.io/star122013/fedora-niri-atomic:latest -f Containerfile .
```

For local testing, you can also use a local tag:

```bash
podman build -t fedora-niri-atomic:dev -f Containerfile .
```

---

### 3. Manually run the real Nu build pipeline

This is usually **not** recommended directly on the host, because it will actually invoke:

- `dnf`
- `flatpak`
- `systemctl`
- `bootc`

But in a suitable container or test environment, you can run:

```bash
nu build/scripts/build.nu build
```

Inside the image build, `Containerfile` already does this automatically:

```dockerfile
COPY build /tmp/build
RUN nu /tmp/build/scripts/build.nu /tmp/build
```

---

### 4. Inspect a specific config section

Show package groups:

```bash
nu -c 'open build/config/packages.nuon | get groups'
```

Show the desktop group:

```bash
nu -c 'open build/config/packages.nuon | get groups.desktop'
```

Show all COPR groups:

```bash
nu -c 'open build/config/repos.nuon | get copr.groups'
```

---

## Common maintenance tasks

### Add a COPR repo
Edit:

- `build/config/repos.nuon`

Common places:

- `copr.groups.desktop`
- `copr.groups.utils`
- `priority_overrides`

---

### Add a normal package
Edit:

- `build/config/packages.nuon`

Put it into the appropriate group, for example:

- `desktop`
- `gaming`
- `utils`
- `fonts`
- `system`

---

### Add a GitHub release RPM
Edit:

- `build/config/extras.nuon`

If it uses a fixed version URL, add it to:

- `static`

If it should always use the latest GitHub release, add it to:

- `github_latest`

---

### Add an enabled service
Edit:

- `build/config/system.nuon`

Location:

- `services.enable`

---

### Add a flatpak remote
Edit:

- `build/config/system.nuon`

Location:

- `flatpak.remotes`

---

---

## Recommended workflow

### When changing config

1. Edit `build/config/*.nuon`
2. Run a dry-run:

```bash
nu build/scripts/build.nu build --dry-run
```

3. Verify the output
4. Run a real build:

```bash
podman build -t fedora-niri-atomic:dev -f Containerfile .
```

---

### When changing build logic

Prefer editing:

- `build/scripts/lib/common.nu`
- `build/scripts/lib/repos.nu`
- `build/scripts/lib/packages.nu`
- `build/scripts/lib/system.nu`

Then run dry-run again.

---

## Why `nushell` bootstrap still exists

Even though the main repo/package/system logic has been moved to Nu, the image must already contain `nushell` before any `.nu` script can run.

So `Containerfile` still keeps a small bootstrap step to:

1. install rpmfusion
2. enable `atim/nushell`
3. install `nushell`

Only after that does it hand over the main build flow to Nu.

This is intentional and required.

---

## CI / publishing

GitHub Actions workflow:

- `.github/workflows/build.yml`

It currently:

- builds on `push`
- builds on schedule
- supports manual dispatch
- pushes to:

```text
ghcr.io/star122013/fedora-niri-atomic:latest
```

---

## Further reading

- [`README-zh.md`](README-zh.md)
- [`build/README.md`](build/README.md)
- [`build/README-zh.md`](build/README-zh.md)
- `Containerfile`

- [`https://bootc.dev/bootc/`](bootc-docs)
- [`https://blue-build.org/`](bluebuild)
