# fedora-niri-atomic

> English version: [README.md](README.md)

基于 [bootc](https://bootc.dev/) 的个人 Fedora Atomic 桌面镜像仓库。

当前目标大致是：

- 以 `quay.io/fedora/fedora-kinoite:44` 为基础
- 提供一个可用的 Wayland 桌面环境
- 保留部分 Hyprland / KDE 生态软件
- 用 `Containerfile + Nu + NUON` 管理仓库、软件包和系统配置

---

## 仓库结构图

```text
.
├── README.md                     # 仓库总说明与 usage（英文）
├── README-zh.md                  # 仓库总说明与 usage（中文）
├── AGENTS.md                     # 给 agent / 自动化工具的仓库说明
├── Containerfile                 # OCI / bootc 镜像构建入口
├── config.toml                   # 用户、时区、locale 等系统定制
├── mise.toml                     # 本地工具链管理
├── .github/
│   └── workflows/
│       └── build.yml             # GitHub Actions：构建并推送镜像
├── build/
│   ├── README.md                 # build 子系统说明（英文）
│   ├── README-zh.md              # build 子系统说明（中文）
│   ├── config/
│   │   ├── repos.nuon            # 仓库配置：rpmfusion / terra / copr / priority
│   │   ├── packages.nuon         # 软件包分组与 remove 列表
│   │   ├── extras.nuon           # 额外 rpm / GitHub latest release
│   │   └── system.nuon           # flatpak remotes / systemd services
│   └── scripts/
│       ├── build.nu              # Nu 总入口
│       └── lib/
│           ├── common.nu         # 公共函数
│           ├── repos.nu          # 仓库阶段逻辑
│           ├── packages.nu       # 软件包阶段逻辑
│           └── system.nu         # 系统阶段逻辑
└── rootfs/                       # 构建时直接复制进镜像文件系统的内容
    ├── etc/
    └── usr/
```

---

## 各部分职责

### `Containerfile`
负责：

- 定义多阶段镜像构建
- 下载字体资源
- bootstrap `nushell`
- 调用 `build/scripts/build.nu`
- 产出最终 bootc/OCI 镜像

它现在主要是一个较薄的编排入口，而不是把所有 repo/package 逻辑都塞进超长的 `RUN dnf ...`。

---

### `build/`
负责整个配置驱动的构建系统：

- `NUON` 文件描述“装什么 / 启用什么”
- `Nu` 脚本描述“怎么执行”

另见：

- [`build/README.md`](build/README.md)
- [`build/README-zh.md`](build/README-zh.md)

---

### `rootfs/`
负责静态文件树：

- systemd 配置
- 环境文件
- 程序配置
- `/etc/nix` 下的 Nix 集成文件
- 其它需要通过 `COPY rootfs/ /` 放入镜像的内容

如果某个东西本质上是“镜像里的文件系统内容”，通常更适合放在这里，而不是由脚本动态生成。

---

### `config.toml`
负责系统自定义参数，例如：

- 用户
- 时区
- locale
- 键盘布局

当前内容包括：

- 用户 `cyrene`
- 时区 `Asia/Shanghai`
- 语言 `zh_CN.UTF-8`

---

### `.github/workflows/build.yml`
负责 CI：

- push 时构建
- 定时构建
- 手动触发构建
- 推送镜像到 `ghcr.io/star122013/fedora-niri-atomic:latest`

---

## build 子系统结构图

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

职责拆分：

- `repos.nuon`：仓库来源与优先级
- `packages.nuon`：包分组与移除列表
- `extras.nuon`：额外 rpm 与 GitHub latest release 逻辑
- `system.nuon`：flatpak / services
- `build.nu`：总入口
- `lib/*.nu`：按阶段拆分逻辑，避免脚本过长

---

## Usage

### 1. 先预览构建计划

修改完 `build/config/*.nuon` 后，推荐先 dry-run：

```bash
nu build/scripts/build.nu build --dry-run
```

短参数：

```bash
nu build/scripts/build.nu build -n
```

这个命令会打印：

- 将启用哪些 repo
- 将安装哪些包
- 将删除哪些包
- 将添加哪些 flatpak remote
- 将启用哪些 systemd service

但**不会真的执行 `dnf` / `systemctl` / `bootc`**。

---

### 2. 在 zmx session 里预览

如果你已经有一个 session，比如 `system-oci`：

```bash
zmx run system-oci -- nu build/scripts/build.nu build --dry-run
```

这很适合远程或 agent 驱动的验证。

---

### 3. 本地构建镜像

```bash
podman build -t ghcr.io/star122013/fedora-niri-atomic:latest -f Containerfile .
```

如果只是本地测试，也可以用本地 tag：

```bash
podman build -t fedora-niri-atomic:dev -f Containerfile .
```

---

### 4. 手动运行真实 Nu 构建流程

通常不建议直接在宿主机上执行，因为它会真的调用：

- `dnf`
- `flatpak`
- `systemctl`
- `bootc`

但如果你在合适的容器或测试环境里，可以运行：

```bash
nu build/scripts/build.nu build
```

在镜像构建里，`Containerfile` 会自动做这件事：

```dockerfile
COPY build /tmp/build
RUN nu /tmp/build/scripts/build.nu /tmp/build
```

---

### 5. 系统级 Nix 图形运行时

现在镜像内置了一套面向非 NixOS 的、系统级的 Nix 图形运行时集成。

包含的文件有：

- `/etc/nix/flake.nix`
- `/etc/nix/nix.conf`
- `/usr/libexec/fedora-nix-graphics-rebuild`
- `fedora-nix-graphics-bootstrap.service`
- `fedora-nix-graphics-rebuild.service`
- `fedora-nix-graphics-rebuild.path`
- `fedora-nix-graphics-link.service`
- `fedora-nix-graphics-link.path`

作用：

- 构建一个 Nix `graphicsDrivers` 环境到 `/var/nix-system/graphics-drivers`
- 将 `/run/opengl-driver` 链接到这个运行时
- 让 Fedora 上的 Nix GUI / GPU 程序拥有类似 NixOS 的图形运行时路径

行为：

- 首次开机会自动运行 `fedora-nix-graphics-bootstrap.service`，如果运行时尚不存在则自动构建
- 当 `/etc/nix/flake.nix` 或 `/etc/nix/nix.conf` 发生变化时，`fedora-nix-graphics-rebuild.path` 会触发 `fedora-nix-graphics-rebuild.service`
- 用户级 `home-manager` 配置有意不放进本仓库，你可以继续放在 `~/.config/home-manager`

手动重建：

```bash
sudo /usr/libexec/fedora-nix-graphics-rebuild
```

### 6. 查看某一类配置

查看包分组：

```bash
nu -c 'open build/config/packages.nuon | get groups'
```

查看桌面组：

```bash
nu -c 'open build/config/packages.nuon | get groups.desktop'
```

查看所有 COPR 分组：

```bash
nu -c 'open build/config/repos.nuon | get copr.groups'
```

---

## 常见维护动作

### 新增一个 COPR
改：

- `build/config/repos.nuon`

常见位置：

- `copr.groups.desktop`
- `copr.groups.utils`
- `priority_overrides`

---

### 新增一个普通包
改：

- `build/config/packages.nuon`

按语义放进对应 group，例如：

- `desktop`
- `gaming`
- `utils`
- `fonts`
- `system`

---

### 新增一个 GitHub release RPM
改：

- `build/config/extras.nuon`

如果是固定版本 URL，放到：

- `static`

如果希望每次都取 latest release，放到：

- `github_latest`

---

### 新增一个开机启用服务
改：

- `build/config/system.nuon`

位置：

- `services.enable`

---

### 新增一个 flatpak remote
改：

- `build/config/system.nuon`

位置：

- `flatpak.remotes`

---

### 修改系统级 Nix 图形运行时
改：

- `rootfs/etc/nix/flake.nix`
- `rootfs/etc/nix/nix.conf`
- `rootfs/usr/libexec/fedora-nix-graphics-rebuild`
- `rootfs/usr/lib/systemd/system/fedora-nix-graphics-bootstrap.service`
- `rootfs/usr/lib/systemd/system/fedora-nix-graphics-rebuild.service`
- `rootfs/usr/lib/systemd/system/fedora-nix-graphics-build.path`
- `rootfs/usr/lib/systemd/system/fedora-nix-graphics-link.service`
- `rootfs/usr/lib/systemd/system/fedora-nix-graphics-link.path`

---

## 推荐工作流

### 改配置时

1. 修改 `build/config/*.nuon`
2. 运行 dry-run：

```bash
nu build/scripts/build.nu build --dry-run
```

3. 检查输出是否符合预期
4. 再执行真实构建：

```bash
podman build -t fedora-niri-atomic:dev -f Containerfile .
```

---

### 改脚本逻辑时

优先修改：

- `build/scripts/lib/common.nu`
- `build/scripts/lib/repos.nu`
- `build/scripts/lib/packages.nu`
- `build/scripts/lib/system.nu`

改完后同样先跑 dry-run。

---

## 为什么还需要 bootstrap nushell

虽然主要的 repo / package / system 逻辑已经交给 Nu 了，
但在运行 `.nu` 脚本之前，镜像里必须先有 `nushell` 本身。

所以 `Containerfile` 里仍保留了一个较小的 bootstrap 步骤，用来：

1. 安装 rpmfusion
2. 启用 `atim/nushell`
3. 安装 `nushell`

之后才把主要构建流程交给 Nu。

这不是多余，而是必需的自举步骤。

---

## CI / 发布

GitHub Actions 工作流：

- `.github/workflows/build.yml`

当前会：

- 在 `push` 时构建
- 定时构建
- 支持手动触发
- 推送到：

```text
ghcr.io/star122013/fedora-niri-atomic:latest
```

---

## 延伸阅读

- [`README.md`](README.md)
- [`build/README.md`](build/README.md)
- [`build/README-zh.md`](build/README-zh.md)
- `Containerfile`
- `rootfs/`
- `config.toml`
