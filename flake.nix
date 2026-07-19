      checks = forAllSystems (
        system:
        let
          repoPolicyCheck = mkScriptCheck system "repo-policy" "tests/repo-policy.sh";
          steamvrToolsCheck = mkScriptCheck system "steamvr-tools" "tests/steamvr-tools.sh";
        in
        {
          formatting = mkFormattingCheck system;
          repo-policy = repoPolicyCheck;
        }
        // nixpkgs.lib.optionalAttrs (system == linuxSystem) {
          steamvr-tools = steamvrToolsCheck;
        }
      );
