{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    # Unity 2022.x requires libxml2.so.2 compatibility for nix-ld.
    nixpkgs-compat.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-steam.url = "github:NixOS/nixpkgs/75563f8f5237c44ed7b8a51fd870ed3d6a11eb82";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };
    homebrew-tap = {
      url = "github:BarutSRB/homebrew-tap";
      flake = false;
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
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
    nixpkgs-xr.url = "github:nix-community/nixpkgs-xr";
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    codex-cli-nix.url = "github:sadjow/codex-cli-nix";
    opencode.url = "github:anomalyco/opencode";
    # Newer OpenCode revisions currently segfault on this WSL2 kernel.
    # Keep WSL on a known-good revision and let native hosts track stable.
    opencode-wsl.url = "github:anomalyco/opencode/500dcfc";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-steam,
      home-manager,
      nix-darwin,
      niri,
      nixos-wsl,
      nixpkgs-xr,
      codex-cli-nix,
      opencode,
      ...
    }@inputs:
    let
      linuxSystem = "x86_64-linux";
      laptopSystem = "aarch64-linux";
      darwinSystem = "aarch64-darwin";

      darwinUser = {
        name = "see2et";
        home = "/Users/see2et";
      };

      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = nixpkgs.lib.optionals (system == darwinSystem) [
            (import ./overlays/darwin/direnv.nix)
          ];
        };

      pkgsDarwin = mkPkgs darwinSystem;

      darwinHomeProfile = ./home/darwin/profile.nix;

      darwinHomeExtraSpecialArgs = {
        inherit inputs;
        inherit darwinUser;
        isDarwin = true;
        hostId = "darwin";
        rustToolchain = pkgsDarwin.rustc;
        opencodePackage = inputs.opencode.packages.${darwinSystem}.opencode;
      };
    in
    {
      nixosConfigurations = {
        desktop = nixpkgs.lib.nixosSystem {
          system = linuxSystem;
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/desktop
          ];
        };

        laptop = nixpkgs.lib.nixosSystem {
          system = laptopSystem;
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/laptop
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

      darwinConfigurations = {
        darwin = nix-darwin.lib.darwinSystem {
          system = darwinSystem;
          specialArgs = {
            inherit inputs darwinUser;
          };
          modules = [
            ./hosts/darwin
          ];
        };
      };

      homeConfigurations = {
        darwin = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsDarwin;
          modules = [
            darwinHomeProfile
          ];
          extraSpecialArgs = darwinHomeExtraSpecialArgs;
        };
      };
    };
}
