# Redirect $HOME to /var/home/<user> to avoid Nix issues with /home being a symlink.
# bootc creates /home -> /var/home, but Nix requires /home to be a real directory.
if [ -L "$HOME" ] && [ -d "/var/home/$(whoami)" ]; then
    export HOME=/var/home/$(whoami)
fi
