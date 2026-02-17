{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    catppuccin.url = "github:catppuccin/nix";
    nixpkgs-xr.url = "github:nix-community/nixpkgs-xr";
    codex-cli-nix.url = "github:sadjow/codex-cli-nix";
    opencode.url = "github:albertov/opencode/dev";
  };

  outputs = { self, nixpkgs, home-manager, niri, nixos-wsl, catppuccin, nixpkgs-xr, codex-cli-nix, opencode, ... }@inputs :
  let
    linuxSystem = "x86_64-linux";
    darwinSystem = "aarch64-darwin";

    mkPkgs =
      system:
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

    pkgsDarwin = mkPkgs darwinSystem;
  in {
    nixosConfigurations = {
      desktop = nixpkgs.lib.nixosSystem {
        system = linuxSystem;
        specialArgs = { inherit inputs; };
        modules = [
          ./configuration.nix

          niri.nixosModules.niri
          nixpkgs-xr.nixosModules.nixpkgs-xr

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.see2et = import ./home.nix;
          }
        ];
      };

      wsl = nixpkgs.lib.nixosSystem {
        system = linuxSystem;
        specialArgs = { inherit inputs; };
        modules = [
          nixos-wsl.nixosModules.default
          {
            system.stateVersion = "25.11";
            wsl.enable = true;
          }
        ];
      };
    };

    homeConfigurations = {
      darwin = home-manager.lib.homeManagerConfiguration {
        pkgs = pkgsDarwin;
        modules = [
          {
            home.username = "see2et";
            home.homeDirectory = "/Users/see2et";
            home.stateVersion = "25.11";
            programs.home-manager.enable = true;
          }
        ];
        extraSpecialArgs = {
          inherit inputs;
          isDarwin = true;
          rustToolchain = pkgsDarwin.rustc;
        };
      };
    };
  };
}
