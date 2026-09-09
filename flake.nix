{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Unity 2022.x requires libxml2.so.2 compatibility for nix-ld.
    nixpkgs-compat.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-26.05";
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
    dms = {
      url = "github:AvengeMedia/DankMaterialShell/v1.5.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl.url = "github:nix-community/NixOS-WSL/release-26.05";
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
    voxtype = {
      url = "github:peteonrails/voxtype/v1.0.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-cli-nix.url = "github:sadjow/codex-cli-nix";
    opencode.url = "github:anomalyco/opencode";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      ...
    }@inputs:
    let
      linuxSystem = "x86_64-linux";
      darwinSystem = "aarch64-darwin";
      systems = [
        linuxSystem
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
            nixfmt
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

      mkScriptCheck =
        system: name: scriptPath:
        let
          pkgs = mkPkgs system;
        in
        pkgs.runCommand name
          {
            nativeBuildInputs = with pkgs; [
              bash
              binutils
              coreutils
              findutils
              gnugrep
              jq
            ];
            src = self;
          }
          ''
            export HOME="$TMPDIR"
            worktree="$TMPDIR/flake-src"
            mkdir -p "$worktree"
            cp -a "$src"/. "$worktree"
            chmod -R u+rwX "$worktree"
            cd "$worktree"
            printf '%s: running %s from %s\n' "${name}" "./${scriptPath}" "$PWD"
            bash "./${scriptPath}"
            touch "$out"
          '';

      pkgsLinux = mkPkgs linuxSystem;
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
        system: release:
        let
          pkgs = mkPkgs system;
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

      opencodePackageLinux = mkOpencodeReleasePackage linuxSystem {
        url = "https://github.com/anomalyco/opencode/releases/download/v1.18.30/opencode-linux-x64-baseline.tar.gz";
        hash = "sha256-cB72253PPAD6+r/7K9HeWQA6oT7F0u+Xazf/QASB3RM=";
      };

      # Use the same v1.18.30 baseline as Desktop.
      opencodePackageWsl = mkOpencodeReleasePackage linuxSystem {
        url = "https://github.com/anomalyco/opencode/releases/download/v1.18.30/opencode-linux-x64-baseline.tar.gz";
        hash = "sha256-cB72253PPAD6+r/7K9HeWQA6oT7F0u+Xazf/QASB3RM=";
      };

      dmsPackage = inputs.dms.packages.${linuxSystem}.default.overrideAttrs (oldAttrs: {
        patches = (oldAttrs.patches or [ ]) ++ [
          ./patches/dms-core-disable-unauthenticated-unlock.patch
          ./patches/dms-core-pin-suspend-lock.patch
        ];
        nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgsLinux.patch ];
        postInstall = oldAttrs.postInstall + ''
          chmod -R u+w "$out/share/quickshell/dms"
          ${pkgsLinux.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" < ${./patches/dms-qml-disable-unauthenticated-unlock.patch}
          ${pkgsLinux.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" < ${./patches/dms-qml-pin-pam-auth-boundary.patch}
          ${pkgsLinux.patch}/bin/patch -p1 -d "$out/share/quickshell/dms" < ${./patches/dms-qml-pin-lock-control.patch}
        '';
      });

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
            inherit dmsPackage;
            opencodePackage = opencodePackageLinux;
          };
          modules = [
            ./hosts/desktop
          ];
        };

        wsl = nixpkgs.lib.nixosSystem {
          system = linuxSystem;
          specialArgs = { inherit inputs opencodePackageWsl; };
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

      checks = forAllSystems (
        system:
        let
          repoPolicyCheck = mkScriptCheck system "repo-policy" "tests/repo-policy.sh";
          dmsShellPolicyCheck = mkScriptCheck system "dms-shell-policy" "tests/dms-shell-policy.sh";
          niriPipWorkspaceFollowerCheck =
            let
              service =
                self.nixosConfigurations.desktop.config.home-manager.users.see2et.systemd.user.services.niri-pip-workspace-follower.Service;
            in
            assert service.Restart == "always";
            assert service.RestartSec == 1;
            mkScriptCheck system "niri-pip-workspace-follower" "tests/niri-pip-workspace-follower.sh";
          steamvrToolsCheck = mkScriptCheck system "steamvr-tools" "tests/steamvr-tools.sh";
          dmsCodexUsageCheck =
            let
              pkgs = mkPkgs system;
              dmsCodexUsage = import ./home/desktop/dms/codex-usage.nix { inherit pkgs; };
            in
            pkgs.runCommand "dms-codex-usage-check" { nativeBuildInputs = [ pkgs.gnugrep ]; } ''
              ${dmsCodexUsage}/bin/dms-codex-usage --self-test | grep -Fx 'dms-codex-usage self-test: ok'
              touch "$out"
            '';
          dmsSecurityCheck =
            let
              pkgs = mkPkgs system;
            in
            pkgs.runCommand "dms-security"
              {
                nativeBuildInputs = with pkgs; [
                  binutils
                  coreutils
                  gnugrep
                ];
              }
              ''
                lock_qml="${dmsPackage}/share/quickshell/dms/Modules/Lock/Lock.qml"
                lock_content_qml="${dmsPackage}/share/quickshell/dms/Modules/Lock/LockScreenContent.qml"
                pam_qml="${dmsPackage}/share/quickshell/dms/Modules/Lock/Pam.qml"
                dms_service_qml="${dmsPackage}/share/quickshell/dms/Services/DMSService.qml"
                idle_service_qml="${dmsPackage}/share/quickshell/dms/Services/IdleService.qml"
                session_service_qml="${dmsPackage}/share/quickshell/dms/Services/SessionService.qml"
                wrapped_bin="${dmsPackage}/bin/.dms-wrapped"

                test "$(grep -c 'function unlock()' "$lock_qml")" -eq 1
                ! grep -n 'forceReset' "$lock_qml"
                ! grep -n 'loginctl\.unlock' "$dms_service_qml"
                ! strings "$wrapped_bin" | grep -F 'loginctl.unlock'
                grep -F 'config: "dankshell"' "$pam_qml"
                grep -F 'configDirectory: "/etc/pam.d"' "$pam_qml"
                ! grep -E 'SettingsData\.lock(PamPath|U2fPamPath|PamExternallyManaged|PamInline)' "$pam_qml"
                ! grep -F 'userPamDir' "$pam_qml"
                ! grep -F 'resolve-lock' "$pam_qml"
                ! grep -F 'lockComponent' "$lock_qml" "$idle_service_qml"
                ! grep -F 'customPowerActionLock' "$lock_qml"
                ! grep -F 'handleLoginctlCustomLock' "$lock_qml"
                ! grep -F 'SettingsData.loginctlLockIntegration' "$lock_qml" "$session_service_qml"
                ! grep -F 'loginctl.lockerReady' "$lock_content_qml"
                ! grep -E 'loginctl\.(setLockBeforeSuspend|setSleepInhibitorEnabled)' "$session_service_qml"
                grep -F 'SETTINGS_PROTECTED_KEY' "${dmsPackage}/share/quickshell/dms/DMSShellIPC.qml"
                ! strings "$wrapped_bin" | grep -E 'loginctl\.(setLockBeforeSuspend|setSleepInhibitorEnabled|lockerReady)'

                touch "$out"
              '';
        in
        {
          formatting = mkFormattingCheck system;
          repo-policy = repoPolicyCheck;
        }
        // nixpkgs.lib.optionalAttrs (system == linuxSystem) {
          dms-security = dmsSecurityCheck;
          dms-codex-usage = dmsCodexUsageCheck;
          dms-shell-policy = dmsShellPolicyCheck;
          niri-pip-workspace-follower = niriPipWorkspaceFollowerCheck;
          steamvr-tools = steamvrToolsCheck;
        }
      );

      formatter = forAllSystems mkFormatter;
    };
}
