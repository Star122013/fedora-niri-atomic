# build subsystem

> 中文版本：[`README-zh.md`](README-zh.md)

This build layout moves most repo / package / system configuration out of `Containerfile` and into a small Nu + NUON build subsystem.

- `NUON` describes **what** to enable or install
- `Nu` describes **how** the build steps are executed

Goals:

- keep `Containerfile` shorter and easier to read
- make repos, packages, and services easier to maintain
- support `--dry-run` previews
- avoid putting all logic into one huge `RUN dnf ...` block

---

## File layout

```text
build/
├── README.md                     # this document (English)
├── README-zh.md                  # this document (Chinese)
├── config/
│   ├── repos.nuon                # repo config: rpmfusion / terra / copr / priority
│   ├── packages.nuon             # package groups and removal list
│   ├── extras.nuon               # extra RPMs: fixed URLs / GitHub latest
│   └── system.nuon               # flatpak remotes and systemd services
└── scripts/
    ├── build.nu                  # top-level entrypoint: runs repos / packages / system stages
    └── lib/
        ├── common.nu             # shared helpers: printing, dry-run, config loading, dnf helpers
        ├── repos.nu              # repo stage: rpmfusion / rawhide / terra / copr / priority
        ├── packages.nu           # package stage: packages, removals, extra RPMs
        └── system.nu             # system stage: flatpak, fc-cache, services, bootc lint
```

---

## Structure and responsibilities

### 1. `config/repos.nuon`
Repo-related configuration:

- rpmfusion release URL templates
- `dnf config-manager setopt`
- disabling `*rawhide*` repos
- terra repo and `terra-release`
- COPR groups
- repo `priority=1` overrides

Typical edits:

- add / remove a COPR repo
- change repo enable order
- add priority to a repo file
- adjust terra / rpmfusion settings

---

### 2. `config/packages.nuon`
Package group configuration:

- `desktop`
- `gaming`
- `utils`
- `fonts`
- `system`
- `remove`

Typical edits:

- add or remove packages from a group
- adjust install order
- add a new package group
- add a package to the removal list

---

### 3. `config/extras.nuon`
Extra RPM sources that are not ordinary named packages:

- fixed download URL RPMs
- GitHub latest-release RPMs
- fonts downloaded from a direct URL (raw `.ttf`/`.otf` or an archive like `.zip`/
  `.tar.gz`/`.tar.xz`/`.tar.bz2`/`.7z`), extracted into `/usr/share/fonts`

Typical edits:

- update `cc-switch`
- add a new GitHub release install entry
- adjust `FlClash` download template
- add a font from any direct download URL

A font entry looks like:

```nuon
fonts: [
  {
    name: "LXGW WenKai GB"
    url: "https://github.com/lxgw/LxgwWenkaiGB/releases/download/v1.522/lxgw-wenkai-gb-v1.522.tar.gz"
    dest_dir: "/usr/share/fonts/lxgw-wenkai-gb"
  }
]

# a plain single file also works (no extraction):
fonts: [
  {
    name: "Some Font"
    url: "https://example.com/path/font.ttf"
    dest_dir: "/usr/share/fonts/custom"
  }
]
```

`url` may point to any host (not just GitHub). Archives are detected by file extension and
unpacked into `dest_dir`; plain `.ttf`/`.otf` files are copied as-is. `fc-cache` (system
stage) indexes them afterwards. Requires `curl`, `unzip`, and `p7zip` (already in the
`utils` package group).
---

### 4. `config/system.nuon`
System-level configuration:

- flatpak remotes
- services to enable with `systemctl enable`

Typical edits:

- add a flatpak remote
- add or remove an enabled service

---

## Script responsibilities

### `scripts/build.nu`
Top-level orchestrator.

It only:

1. finds the `build/` root
2. loads all `nuon` config files
3. runs the three stages in order:
   - repo stage
   - package stage
   - system stage

---

### `scripts/lib/common.nu`
Shared utilities.

Includes helpers such as:

- `print-step`
- `print-bullets`
- `run-cmd`
- `resolve-project-root`
- `load-config`
- `dnf-clean`
- `dnf-install-lean`
- `strip-version-prefix`

---

### `scripts/lib/repos.nu`
Repo stage only:

- rpmfusion
- `dnf config-manager setopt`
- disable rawhide
- terra release
- COPR enable
- repo priority override

---

### `scripts/lib/packages.nu`
Package stage only:

- install package groups
- remove packages
- install fixed URL RPMs
- install GitHub latest RPMs

---

### `scripts/lib/system.nu`
System post-processing:

- flatpak remotes
- `fc-cache -fv`
- `systemd-sysusers`
- `systemctl enable`
- `bootc container lint`

---

## Execution flow

```text
build.nu
  ├─ load repos.nuon
  ├─ load packages.nuon
  ├─ load extras.nuon
  ├─ load system.nuon
  │
  ├─ run-repo-stage
  │   ├─ install rpmfusion
  │   ├─ set dnf config-manager options
  │   ├─ disable rawhide repos
  │   ├─ install terra-release
  │   ├─ enable copr groups
  │   └─ apply repo priorities
  │
  ├─ run-package-stage
  │   ├─ install package groups
  │   ├─ remove packages
  │   ├─ install static rpms
  │   └─ install github latest rpms
  │
  └─ run-system-stage
      ├─ configure flatpak remotes
      ├─ refresh font cache
      ├─ enable services
      └─ run bootc container lint
```

---

## Common commands

### 1. Dry-run from the repository root

```bash
nu build/scripts/build.nu build --dry-run
```

Or:

```bash
nu build/scripts/build.nu build -n
```

---

### 2. Dry-run inside a zmx session

```bash
zmx run system-oci -- nu build/scripts/build.nu build --dry-run
```

---

### 3. Run during container build

`Containerfile` currently uses:

```dockerfile
COPY build /tmp/build
RUN nu /tmp/build/scripts/build.nu /tmp/build
```

Note that the argument is the **build root**, not a single config file.

---

## Why the bootstrap step still exists in `Containerfile`

The image must contain `nushell` before any `.nu` script can run.

So `Containerfile` still needs a small bootstrap step to:

1. install rpmfusion
2. enable `atim/nushell` COPR
3. install `nushell`

Only after that can the main repo / package / system flow be delegated to Nu.

---

## Maintenance guidance

### Change packages
Prefer editing:

- `config/packages.nuon`

### Change repos
Prefer editing:

- `config/repos.nuon`

### Change extra RPM sources
Prefer editing:

- `config/extras.nuon`

### Change services or flatpak remotes
Prefer editing:

- `config/system.nuon`

### Change execution logic
Prefer editing:

- `scripts/lib/*.nu`
- `scripts/build.nu`

---

## sing-box (manual enable)

The image ships a sing-box proxy (SOCKS5 upstream for dae) but it is **not enabled by default** — enable it manually:

```bash
# 1. enable the node-config updater service + timer (daily 20:00 fetch of node.json, then restart singbox)
sudo systemctl enable --now singbox-update.timer

# 2. start sing-box itself (config dir /etc/singbox: base.json + node.json auto-merged)
sudo systemctl enable --now singbox.service
```

Relevant files:

- `rootfs/etc/singbox/base.json` — static config (SOCKS5 inbound :2080, outbound selectors, routing rules)
- `rootfs/usr/lib/systemd/system/singbox.service` — runs `sing-box run -C /etc/singbox`
- `rootfs/usr/lib/systemd/system/singbox-update.service` — pulls node config from SubStore
- `rootfs/usr/lib/systemd/system/singbox-update.timer` — daily refresh at 20:00

> Note: the official sing-box RPM ships its own `sing-box.service`; we use `singbox` (no hyphen) to avoid being overwritten.

---

## Recommended habit

After changing config, always run:

```bash
nu build/scripts/build.nu build --dry-run
```

Check that:

- install order is correct
- package groups are correct
- repo priorities are correct
- GitHub latest templates are correct
- services and flatpak remotes are correct

Then do a real image build.

---

## Related docs

- [`README-zh.md`](README-zh.md)
- [`../README.md`](../README.md)
- [`../README-zh.md`](../README-zh.md)
