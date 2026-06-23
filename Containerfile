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

COPY rootfs/ /
COPY build /tmp/build

# bootstrap nushell, then let Nu orchestrate repos/packages/services
RUN dnf install -y \
    https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
    'dnf5-command(copr)' \
    && dnf copr enable -y atim/nushell \
    && dnf install -y nushell \
    && dnf clean all

# COPY --from=fonts-downloader /fonts /usr/share/fonts/
RUN nu /tmp/build/scripts/build.nu /tmp/build
