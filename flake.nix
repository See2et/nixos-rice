{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-steam.url = "github:NixOS/nixpkgs/75563f8f5237c44ed7b8a51fd870ed3d6a11eb82";

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
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    codex-cli-nix.url = "github:sadjow/codex-cli-nix";
    opencode.url = "github:albertov/opencode/dev";
  };

  outputs = { self, nixpkgs, nixpkgs-steam, home-manager, niri, nixos-wsl, catppuccin, nixpkgs-xr, codex-cli-nix, opencode, ... }@inputs :
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
          ./hosts/desktop
        ];
      };

      wsl = nixpkgs.lib.nixosSystem {
        system = linuxSystem;
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/wsl
        ];
      };
    };

    homeConfigurations = {
      darwin = home-manager.lib.homeManagerConfiguration {
        pkgs = pkgsDarwin;
        modules = [
          ./home/common
          ./home/darwin
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
          hostId = "darwin";
          rustToolchain = pkgsDarwin.rustc;
        };
      };
    };
  };
}
