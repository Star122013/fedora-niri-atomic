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

# stage 2 make system container
FROM quay.io/fedora/fedora-kinoite:43

RUN dnf update -y && dnf upgrade -y && dnf5 install 'dnf5-command(config-manager)' -y

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
# RUN mkdir -p /run && touch /run/ostree-booted \
#   && dnf copr enable bieszczaders/kernel-cachyos-lto -y \
#   && printf '\npriority=1\n' >> /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos-lto.repo \
#   && dnf copr enable bieszczaders/kernel-cachyos-addons -y \
#   && printf '\npriority=1\n' >> /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos-addons.repo \
#   && dnf clean all


# 3.niri session and base kde desktop
# COPY --from=niri-builder /out/runtime /
RUN dnf install -y --nodocs \
  plasma-desktop \
  libseat \
  xdg-desktop-portal-gnome \
  xdg-desktop-portal-gtk \
  xwayland-satellite \
  && dnf copr enable yalter/niri-git -y \
  && test -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:yalter:niri-git.repo \
  && printf '\npriority=1\n' >> /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:yalter:niri-git.repo \
  && dnf install -y niri \
  && dnf clean all

# 4.audio
RUN dnf install -y --setopt=install_weak_deps=False --nodocs \
  pipewire \
  pipewire-pulseaudio \
  pipewire-alsa \
  wireplumber \
  rtkit \
  && dnf clean all

# 5.system service
RUN dnf install -y --setopt=install_weak_deps=False --nodocs \
  NetworkManager \
  bluez \
  bluez-obexd \
  polkit \
  udisks2 \
  gnome-keyring \
  avahi \
  nss-mdns \
  firewalld \
  fwupd \
  && dnf clean all

# 6.system utilities + bootstrap terminal
RUN dnf install -y --setopt=install_weak_deps=False --nodocs \
  foot \
  xdg-user-dirs \
  xdg-utils \
  dconf \
  libnotify \
  git \
  wget \
  curl \
  distrobox \
  && dnf clean all

# 7.base fonts
RUN dnf install -y --setopt=install_weak_deps=False --nodocs \
  google-noto-sans-fonts \
  google-noto-emoji-fonts \
  && dnf clean all

# 8.nix
RUN dnf install -y --setopt=install_weak_deps=False --nodocs \
  nix \
  nix-daemon \
  && dnf clean all

# The nix RPM %post may create /nix as a real directory during the container build.
# At runtime bootc's / is read-only, so systemd-tmpfiles cannot replace a directory
# with a symlink. Force it here: /nix must be a symlink to /var/nix (persistent /var).
# tmpfiles.d/nix-storage.conf creates /var/nix at first boot.
# inspired by https://gitlab.com/ThePhatLee/fedora-hyprland-atomic-deletion_scheduled-81102414
RUN rm -rf /nix 2>/dev/null || true \
  && ln -sf /var/nix /nix

# 9.zram
RUN dnf install -y --setopt=install_weak_deps=False --nodocs \
  zram-generator \
  && dnf clean all

# 10.selinux
RUN restorecon -RFv \
  /usr/lib/bootc \
  /usr/lib/dracut \
  /usr/lib/modprobe.d \
  /usr/lib/sddm \
  /usr/lib/sysusers.d \
  /usr/lib/systemd \
  /usr/lib/tmpfiles.d \
  /usr/share/wayland-sessions \
  /etc/containers \
  /etc/environment \
  /etc/locale.conf \
  /etc/skel \
  2>/dev/null || true \
  && systemd-sysusers


# 11.systemctl
RUN systemctl enable bluetooth.service \
  && systemctl enable nix-daemon.service \
  && systemctl enable firewalld.service \
  && systemctl enable avahi-daemon.service \
  && systemctl enable nix-home-link.service

# 13.bootc lint
RUN bootc container lint
