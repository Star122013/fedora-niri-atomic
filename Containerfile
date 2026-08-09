# vim: set filetype=dockerfile
# ================================================================
# Fedora 44 with bootc
# https://bootc.dev/bootc/
# Philosophy: the image provides hardware support + a working
# niri session.
#
# File placement rules (bootc):
#   /usr/lib/   — read-only distro defaults (modprobe.d, dracut, systemd, sddm)
#   /etc/       — mutable admin config (containers policy, skel, locale)
#   /var/       — runtime state only; never ship files here; use tmpfiles.d
# ================================================================
# stage 1 use fedora build some software
# maple fonts
# FROM alpine AS fonts-downloader

# RUN apk add --no-cache curl jq unzip

# WORKDIR /fonts

# RUN set -e; \
#   download_and_unzip() { \
#   local repo=$1 file=$2 dest=$3; \
#   local tag=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | jq -r ".tag_name"); \
#   echo "Downloading ${repo} ${tag}..."; \
#   curl -L "https://github.com/${repo}/releases/download/${tag}/${file}" -o "/tmp/${file}"; \
#   mkdir -p "${dest}"; \
#   unzip -q "/tmp/${file}" -d "${dest}"; \
#   rm "/tmp/${file}"; \
#   }; \
#   download_and_unzip "subframe7536/maple-font" "MapleMono-NF-CN.zip" "maple-mono-nf-cn" && \
#   download_and_unzip "ryanoasis/nerd-fonts" "NerdFontsSymbolsOnly.zip" "nerd-fonts-symbols-only"


# stage 2 make system container
FROM quay.io/fedora/fedora-bootc:44

COPY build /tmp/build

# ================================================================
# Layer ordering strategy (stable -> changing) for better caching:
#   L1  bootstrap (rpmfusion + nushell)
#   L2  repo stage (rpmfusion / terra / COPR / priority)
#   L3  system group      (zram, mesa)      -- foundational, rarely churn
#   L4  fonts group       (noto)            -- stable
#   L5  utils group       (toolchain, etc.) -- stable-ish
#   L6  desktop group     (niri, hyprland)  -- changes most often
#   L7  gaming group
#   L8  finalize (removals / extras / font download / clean)
#   L9  system stage (flatpak / services / bootc lint)
# Each RUN is its own layer, so unchanged packages are cached and
# only the layers after a change are rebuilt.
# ================================================================

# L1: bootstrap nushell, then let Nu orchestrate repos/packages/services
RUN dnf install -y \
    https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
    'dnf5-command(copr)' \
    && dnf copr enable -y atim/nushell \
    && dnf install -y nushell \
    && dnf clean all

# L2: repo stage
RUN nu /tmp/build/scripts/build.nu /tmp/build --stage repo

# L3-L7: install package groups, stable first
RUN nu /tmp/build/scripts/build.nu /tmp/build --stage packages --group system
RUN nu /tmp/build/scripts/build.nu /tmp/build --stage packages --group fonts
RUN nu /tmp/build/scripts/build.nu /tmp/build --stage packages --group utils
RUN nu /tmp/build/scripts/build.nu /tmp/build --stage packages --group desktop
RUN nu /tmp/build/scripts/build.nu /tmp/build --stage packages --group gaming

# L8: removals / reinstalls / static & github-latest RPMs / font download + clean
RUN nu /tmp/build/scripts/build.nu /tmp/build --stage finalize

# pre-copy custom systemd units (nix.mount, etc.) so systemctl enable can find them
COPY rootfs/usr/lib/systemd/system/ /usr/lib/systemd/system/

# L9: flatpak remotes / font cache / systemd services / bootc lint
RUN nu /tmp/build/scripts/build.nu /tmp/build --stage system

# re-apply rootfs after package install so RPM-shipped /etc defaults
# (e.g. dae's empty /etc/dae/config.dae) do not clobber our config
COPY rootfs/ /

# dae requires config.dae to be 0600. git does not preserve full file
# modes (only the executable bit), so a fresh checkout may yield 0644;
# enforce 0600 at build time instead of relying on the source mode.
RUN chmod 0600 /etc/dae/config.dae
