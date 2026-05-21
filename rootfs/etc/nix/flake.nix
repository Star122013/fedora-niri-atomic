{
  description = "System-level Nix graphics runtime for Fedora bootc";

  inputs = {
    # Prefer a domestic Git mirror for first-boot bootstrap on networks without GitHub access.
    # Keep using a git-based flake input so revisions can still be locked.
    # SJTUG is preferred for binary cache in this repo, but does not currently document a nixpkgs.git mirror here,
    # so use NJU for flakes input fetching and keep other common mirrors as easy fallbacks.
    nixpkgs.url = "git+https://mirrors.nju.edu.cn/git/nixpkgs.git?ref=nixos-unstable&shallow=1";
    # nixpkgs.url = "git+https://mirrors.tuna.tsinghua.edu.cn/git/nixpkgs.git?ref=nixos-unstable&shallow=1";
    # nixpkgs.url = "https://mirrors.ustc.edu.cn/nix-channels/nixos-unstable/nixexprs.tar.xz";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      # forAllSystems = f:
      #   builtins.listToAttrs (map (system: {
      #     name = system;
      #     value = f system;
      #   }) systems);
      lib = nixpkgs.lib;
      forAllSystems = f: lib.genAttrs systems f;
    in {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in {
          graphicsDrivers = pkgs.buildEnv {
            name = "system-nix-graphics-driver";
            paths = with pkgs; [
              mesa
              mesa.drivers
              vulkan-loader
              libglvnd
              libvdpau-va-gl
              intel-media-driver
            ];
          };
        });
    };
}
