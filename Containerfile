# vim: set filetype=dockerfile
# ================================================================
# Fedora 44 with bootc 
# https://bootc.dev/bootc/
# Philosophy: the image provides hardware support + a working
# niri session. Everything user-facing (waybar, rofi,
# terminals, theming, fonts) is managed via Nix.
#
# File placement rules (bootc):
#   /usr/lib/   — read-only distro defaults (modprobe.d, dracut, systemd, sddm)
#   /etc/       — mutable admin config (containers policy, skel, locale)
#   /var/       — runtime state only; never ship files here; use tmpfiles.d
# ================================================================


# stage 1 use fedora build some software
# niri-builder
# use niri copr instead
# maple fonts
FROM alpine AS fonts-downloader
RUN apk add --no-cache curl jq unzip \
  && TAG=$(curl -s https://api.github.com/repos/subframe7536/maple-font/releases/latest | jq -r ".tag_name") \
  && echo latest_verion: ${TAG} \
  && FILE="MapleMono-NF-CN.zip" \
  && DOWNLOAD_URL="https://github.com/subframe7536/maple-font/releases/download/${TAG}/${FILE}" \
  && curl -L ${DOWNLOAD_URL} -o /tmp/${FILE} \
  && unzip /tmp/${FILE} -d /maple-mono-nf-cn
  

# stage 2 make system container
FROM quay.io/fedora/fedora-kinoite:43

COPY rootfs/ /

# 1.package repo enable 
RUN dnf install -y \
  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
  && dnf config-manager setopt fedora-cisco-openh264.enabled=1 \
  && (ls /etc/yum.repos.d/*rawhide* 2>/dev/null && find /etc/yum.repos.d/ -name '*rawhide*' -exec sed -i 's/^enabled=1/enabled=0/g' {} + || echo "no rawhide repos found, skipping")
# && sed -i 's/^enabled=0/enabled=1' /etc/yum.repos.d/rpmfusion-nonfree.repo \
# && sed -i 's/^enabled=0/enabled=1' /etc/yum.repos.d/rpmfusion-nonfree-updates.repo 

# 2.kernel 
RUN mkdir -p /run && touch /run/ostree-booted \
  && dnf copr enable bieszczaders/kernel-cachyos-lto -y \
  && printf '\npriority=1\n' >> /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos-lto.repo \
  && dnf copr enable bieszczaders/kernel-cachyos-addons -y \
  && printf '\npriority=1\n' >> /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos-addons.repo \
  && dnf clean all

# 3.desktop
# COPY --from=niri-builder /out/runtime /
RUN dnf install -y --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release \
  && dnf copr enable -y deltacopy/plasma6-applets-kara \
  && dnf copr enable hazel-bunny/ricing -y \
  && dnf copr enable qwerhyy/misc-packages -y \
  && dnf copr enable jkinred/satty -y \
  && dnf copr enable alternateved/cliphist -y \
  && dnf copr enable errornointernet/quickshell -y \
  && dnf copr enable solopasha/hyprland -y \
  && dnf copr enable yalter/niri-git -y \
  && test -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:yalter:niri-git.repo \
  && printf '\npriority=1\n' >> /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:yalter:niri-git.repo \
  && dnf install -y --setopt=install_weak_deps=False --nodocs \
  plasma6-applets-kara kwin-scripts-krohnkite \
  xdg-desktop-portal-gnome xdg-desktop-portal-gtk \
  xwayland-satellite \
  noctalia-shell-git noctalia-qs \
  cliphist matugen brightnessctl qt6-qtmultimedia \
  grim slurp satty \
  niri \
  && dnf clean all

# # 4.audio
# RUN dnf install -y --setopt=install_weak_deps=False --nodocs \
#   pipewire \
#   pipewire-pulseaudio \
#   pipewire-alsa \
#   wireplumber \
#   rtkit \
#   && dnf clean all

# # 5.system service
# RUN dnf install -y --setopt=install_weak_deps=False --nodocs \
#   NetworkManager \
#   bluez \
#   bluez-obexd \
#   polkit \
#   udisks2 \
#   gnome-keyring \
#   avahi \
#   nss-mdns \
#   firewalld \
#   fwupd \
#   && dnf clean all

# 6.system utilities + bootstrap terminal
RUN dnf copr enable -y atim/starship \
  && dnf copr enable -y atim/nushell \
  && dnf copr enable -y aldantanneo/jj-vcs \
  && dnf copr enable -y jdxcode/mise \
  && dnf copr enable -y anatta/television \
  && dnf copr enable -y zhullyb/v2rayA \
  && dnf copr enable -y lihaohong/yazi \
  && dnf copr enable -y solopasha/hyprland \
  && dnf install -y --setopt=install_weak_deps=False --nodocs \
  foot \
  kitty \
  xdg-user-dirs \
  xdg-utils \
  dconf \
  libnotify \
  cliphist \
  git \
  wget \
  curl \
  distrobox \
  chezmoi \
  nushell \
  starship \
  jj-cli \
  zoxide \
  rg \
  fd \
  jq \
  bat \
  tealdeer \
  television \  
  yazi \
  mise \
  helix \
  fastfetch \
  uv \
  pixi \
  dae \
  && dnf clean all

# 7.base fonts
RUN dnf install -y --setopt=install_weak_deps=False --nodocs \
  google-noto-sans-fonts \
  google-noto-emoji-fonts \
  && dnf clean all
COPY --from=fonts-downloader /maple-mono-nf-cn /usr/share/fonts/
RUN fc-cache -fv

# 8.nix
# RUN dnf install -y --nodocs \
#   nix \
#   nix-daemon \
#   nix-legacy \
#   && dnf clean all

# The nix RPM %post creates /nix as a real directory during container build.
# bootc's / is read-only at runtime so this /nix persists — the
# nix-store-mount.service bind-mounts /var/nix over it to share the store.
# RUN mkdir -p /var/nix

# 9. flatpak
RUN flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# 10.zram
RUN dnf install -y --setopt=install_weak_deps=False --nodocs \
  zram-generator \
  && dnf clean all

# 11.selinux
# RUN restorecon -RFv \
#   /usr/lib/bootc \
#   /usr/lib/dracut \
#   /usr/lib/modprobe.d \
#   /usr/lib/sddm \
#   /usr/lib/sysusers.d \
#   /usr/lib/systemd \
#   /usr/lib/tmpfiles.d \
#   /usr/share/wayland-sessions \
#   /etc/containers \
#   /etc/environment \
#   /etc/locale.conf \
#   /etc/skel \
#   2>/dev/null || true \
#   && systemd-sysusers


# 12.systemctl
RUN systemd-sysusers \
  &&systemctl enable bluetooth.service \
  # && systemctl enable nix.mount \
  # && systemctl enable nix-daemon.service \
  && systemctl enable firewalld.service \
  && systemctl enable avahi-daemon.service

# 13.bootc lint
RUN bootc container lint
