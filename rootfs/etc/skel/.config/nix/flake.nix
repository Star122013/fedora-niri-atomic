{
  description = "User environment via home-manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
    in {
      homeConfigurations = home-manager.lib.homeManagerConfiguration {
        inherit system;

        configuration = { pkgs, ... }: {
          home.username = builtins.getEnv "USER";
          home.homeDirectory = "/var/home/${builtins.getEnv "USER"}";
          home.stateVersion = "24.05";

          home.packages = with pkgs; [
            git
            wget
            curl
          ];

          programs.home-manager.enable = true;
        };
      };
    };
}
