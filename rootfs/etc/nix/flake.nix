{
  description = "System-level Nix graphics runtime for Fedora bootc";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f:
        builtins.listToAttrs (map (system: {
          name = system;
          value = f system;
        }) systems);
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
