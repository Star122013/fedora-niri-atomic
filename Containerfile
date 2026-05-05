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
# niri-builder
# use niri copr instead
# maple fonts
FROM alpine AS fonts-downloader

RUN apk add --no-cache curl jq unzip

WORKDIR /fonts

RUN set -e; \
  download_and_unzip() { \
    local repo=$1 file=$2 dest=$3; \
    local tag=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | jq -r ".tag_name"); \
    echo "Downloading ${repo} ${tag}..."; \
    curl -L "https://github.com/${repo}/releases/download/${tag}/${file}" -o "/tmp/${file}"; \
    mkdir -p "${dest}"; \
    unzip -q "/tmp/${file}" -d "${dest}"; \
    rm "/tmp/${file}"; \
  }; \
  download_and_unzip "subframe7536/maple-font" "MapleMono-NF-CN.zip" "maple-mono-nf-cn" && \
  download_and_unzip "ryanoasis/nerd-fonts" "NerdFontsSymbolsOnly.zip" "nerd-fonts-symbols-only"

# FROM fedora AS grub-builder
# RUN dnf install -y curl git dialog bash 
# WORKDIR /tmp
# RUN git clone https://github.com/vinceliuice/Elegant-grub2-themes.git
# WORKDIR /tmp/Elegant-grub2-themes
# RUN mkdir -p output && \
#   bash generate.sh -t forest -p window -i left -c light -s 2k -d output/
# RUN mkdir -p /usr/share/grub/themes && \
#   cp -r output/Elegant-forest-window-left-light /usr/share/grub/themes/elegant  

# stage 2 make system container
FROM quay.io/fedora/fedora-kinoite:44

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
RUN dnf copr enable bieszczaders/kernel-cachyos-lto -y \
  && printf '\npriority=1\n' >> /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos-lto.repo \
  && dnf copr enable bieszczaders/kernel-cachyos-addons -y \
  && printf '\npriority=1\n' >> /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos-addons.repo \
  && dnf clean all
  

# 3.desktop
# COPY --from=niri-builder /out/runtime /
RUN dnf install -y --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release \
  && dnf copr enable qwerhyy/misc-packages -y \
  && dnf copr enable eli-xciv/hyprland -y \
  && dnf copr enable alternateved/cliphist -y \
  && dnf copr enable errornointernet/quickshell -y \
  && dnf copr enable solopasha/hyprland -y \
  && dnf copr enable yalter/niri-git -y \
  && dnf copr enable quadratech188/vicinae -y \
  && dnf copr enable erikreider/SwayNotificationCenter -y \
  && test -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:yalter:niri-git.repo \
  && printf '\npriority=1\n' >> /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:yalter:niri-git.repo \
  && dnf install -y --setopt=install_weak_deps=False --nodocs \
  fcitx5 fcitx5-rime fcitx5-gtk fcitx5-qt fcitx5-configtool \
  adw-gtk3-theme nautilus gtk-murrine-engine \
  xdg-desktop-portal-gnome xdg-desktop-portal-gtk \
  xwayland-satellite wayland-protocols-devel libxkbcommon river \
  noctalia-shell-git noctalia-qs vicinae waybar cava \
  cliphist matugen brightnessctl qt6-qtmultimedia kvantum \
  grim slurp satty \
  niri \
  && dnf install -y lutris gamescope mangohud \
  && dnf remove -y firefox firefox-langpacks \
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
RUN dnf copr enable -y atim/nushell \
  && dnf copr enable -y zhullyb/v2rayA \
  && dnf copr enable -y scottames/ghostty \
  && dnf copr enable -y rivenirvana/kitty \
  && printf '\npriority=1\n' >> /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:rivenirvana:kitty.repo \
  && dnf install -y --setopt=install_weak_deps=False --nodocs \
  git dae nushell distrobox image-builder zathura pixi \
  && dnf install -y https://github.com/farion1231/cc-switch/releases/download/v3.14.1/CC-Switch-v3.14.1-Linux-x86_64.rpm \
  kitty ghostty \
  && TAG=$(curl -s https://api.github.com/repos/chen08209/FlClash/releases/latest | jq -r ".tag_name") \
  && echo latest_verion: ${TAG} \
  && dnf install -y https://github.com/chen08209/FlClash/releases/download/${TAG}/FlClash-${TAG#v}-linux-amd64.rpm \
  && dnf clean all

# 7.base fonts
RUN dnf install -y --setopt=install_weak_deps=False --nodocs \
  google-noto-sans-fonts \
  google-noto-emoji-fonts \
  && dnf clean all
COPY --from=fonts-downloader /fonts /usr/share/fonts/
RUN fc-cache -fv

# 8.grub
# RUN mkdir -p /usr/share/grub/themes
# COPY --from=grub-builder /usr/share/grub/themes/ /usr/share/grub/themes/
# RUN sed -i 's|^GRUB_THEME=.*|GRUB_THEME="/usr/share/grub/themes/elegant/theme.txt"|' /etc/default/grub \
#   && sed -i 's|^GRUB_GFXMODE=.*|GRUB_GFXMODE="1920x1080x32"|' /etc/default/grub \
#   && sed -i 's|^GRUB_DISABLE_OS_PROBER=.*|GRUB_DISABLE_OS_PROBER=false|' /etc/default/grub

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
  # && systemctl enable grub-sync-boot-assets.service \
  && systemctl enable firewalld.service \
  && systemctl enable avahi-daemon.service

# 13.bootc lint
RUN bootc container lint
