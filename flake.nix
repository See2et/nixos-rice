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
      systems = [
        linuxSystem
        laptopSystem
        darwinSystem
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;

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

      mkTreefmtConfig =
        pkgs:
        pkgs.writeText "treefmt.toml" ''
          [formatter.nix]
          command = "nixfmt"
          includes = ["*.nix"]

          [formatter.lua]
          command = "stylua"
          includes = ["*.lua"]

          [formatter.json]
          command = "jq"
          options = ["--indent", "2", "."]
          includes = ["*.json"]
        '';

      mkFormatter =
        system:
        let
          pkgs = mkPkgs system;
          treefmtConfig = mkTreefmtConfig pkgs;
        in
        pkgs.writeShellApplication {
          name = "treefmt-wrapper";
          runtimeInputs = with pkgs; [
            jq
            nixfmt-rfc-style
            stylua
            treefmt
          ];
          text = ''
            exec treefmt --config-file ${treefmtConfig} "$@"
          '';
        };

      mkFormattingCheck =
        system:
        let
          pkgs = mkPkgs system;
        in
        pkgs.runCommand "formatting-check" { nativeBuildInputs = [ (mkFormatter system) ]; } ''
          export HOME="$TMPDIR"
          worktree="$TMPDIR/flake-src"
          cp -R ${self} "$worktree"
          chmod -R u+w "$worktree"
          cd "$worktree"
          treefmt-wrapper --tree-root "$worktree" --ci
          touch "$out"
        '';

      pkgsDarwin = mkPkgs darwinSystem;

      bun114Overlay = final: prev: {
        bun = prev.bun.overrideAttrs (
          finalAttrs: prevAttrs: {
            version = "1.3.14";
            passthru = (prevAttrs.passthru or { }) // {
              sources = (prevAttrs.passthru.sources or { }) // {
                "aarch64-darwin" = prev.fetchurl {
                  url = "https://github.com/oven-sh/bun/releases/download/bun-v1.3.14/bun-darwin-aarch64.zip";
                  hash = "sha256-2LliIYKK1vl6x6wKt+lYcjQa92MAHogD6CZ2UsJlJiA=";
                };
                "x86_64-darwin" = prev.fetchurl {
                  url = "https://github.com/oven-sh/bun/releases/download/bun-v1.3.14/bun-darwin-x64-baseline.zip";
                  hash = "sha256-PjWtb1OXGpg0v55nhuKt9ytfGSHMmpxf3gc9KXKUQHY=";
                };
                "x86_64-linux" = prev.fetchurl {
                  url = "https://github.com/oven-sh/bun/releases/download/bun-v1.3.14/bun-linux-x64.zip";
                  hash = "sha256-lR7iruhV8IWVruxiJSJqKY0/6oOj3NZGXAnLzN9+hI8=";
                };
                "aarch64-linux" = prev.fetchurl {
                  url = "https://github.com/oven-sh/bun/releases/download/bun-v1.3.14/bun-linux-aarch64.zip";
                  hash = "sha256-on/7Y6gxA3WDbg1vZorhf6jY0YuIw3yCHGUzGXOhmjs=";
                };
              };
            };
            src =
              finalAttrs.passthru.sources.${prev.stdenvNoCC.hostPlatform.system}
                or (throw "Unsupported system: ${prev.stdenvNoCC.hostPlatform.system}");
          }
        );
      };

      mkOpencodeReleasePackage =
        system:
        let
          pkgs = mkPkgs system;
          release =
            {
              x86_64-linux = {
                url = "https://github.com/anomalyco/opencode/releases/download/v1.17.9/opencode-linux-x64-baseline.tar.gz";
                hash = "sha256-aqnYgO8KgQBx02ZYZ6rsLhDjn6CktiR4BdElgpJ5ovc=";
              };
              aarch64-linux = {
                url = "https://github.com/anomalyco/opencode/releases/download/v1.17.9/opencode-linux-arm64.tar.gz";
                hash = "sha256-9tjQRCEM56t3iz/da6WXkJZ6KyOf9KUDc4XMpZhyl7E=";
              };
            }
            .${system} or (throw "Unsupported opencode release system: ${system}");
          opencodeBinary = pkgs.fetchzip {
            inherit (release) url hash;
            stripRoot = false;
          };
        in
        pkgs.writeShellScriptBin "opencode" ''
          export PATH="${
            pkgs.lib.makeBinPath [
              pkgs.ripgrep
              pkgs.gitMinimal
            ]
          }:$PATH"
          exec ${opencodeBinary}/opencode "$@"
        '';

      opencodePackageLinux = mkOpencodeReleasePackage linuxSystem;
      opencodePackageLaptop = mkOpencodeReleasePackage laptopSystem;

      opencodePkgsDarwin = import nixpkgs {
        system = darwinSystem;
        config.allowUnfree = true;
        overlays = [
          (import ./overlays/darwin/direnv.nix)
          bun114Overlay
          inputs.opencode.overlays.default
        ];
      };

      opencodePackageDarwin = opencodePkgsDarwin.opencode;

      darwinHomeProfile = ./home/darwin/profile.nix;

      darwinHomeExtraSpecialArgs = {
        inherit inputs;
        inherit darwinUser;
        isDarwin = true;
        hostId = "darwin";
        rustToolchain = pkgsDarwin.rustc;
        opencodePackage = opencodePackageDarwin;
      };
    in
    {
      nixosConfigurations = {
        desktop = nixpkgs.lib.nixosSystem {
          system = linuxSystem;
          specialArgs = {
            inherit inputs;
            opencodePackage = opencodePackageLinux;
          };
          modules = [
            ./hosts/desktop
          ];
        };

        laptop = nixpkgs.lib.nixosSystem {
          system = laptopSystem;
          specialArgs = {
            inherit inputs;
            opencodePackage = opencodePackageLaptop;
          };
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
            inherit inputs darwinUser opencodePackageDarwin;
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

      checks = forAllSystems (system: {
        formatting = mkFormattingCheck system;
      });

      formatter = forAllSystems mkFormatter;
    };
}
