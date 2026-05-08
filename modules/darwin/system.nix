# Darwin system baseline
# Platform-neutral HM config stays in home/common.

{ pkgs, ... }:

{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    (import ../../overlays/darwin/direnv.nix)
  ];

  environment.systemPackages = with pkgs; [
    pnpm
  ];

  system.defaults = {
    CustomSystemPreferences = {
      NSGlobalDomain = {
        AppleMiniaturizeOnDoubleClick = false;
      };

      "com.apple.finder" = {
        ShowSidebar = true;
      };
    };

    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      NSAutomaticCapitalizationEnabled = true;
      NSAutomaticPeriodSubstitutionEnabled = true;
      "com.apple.mouse.tapBehavior" = 1;
      "com.apple.springing.delay" = 0.5;
      "com.apple.springing.enabled" = true;
      "com.apple.trackpad.forceClick" = true;
      "com.apple.trackpad.scaling" = 3.0;
    };

    dock = {
      autohide = true;
      tilesize = 62;
      wvous-tl-corner = 1;
      wvous-tr-corner = 1;
      wvous-bl-corner = 1;
      wvous-br-corner = 1;
    };

    finder = {
      FXPreferredViewStyle = "clmv";
      FXRemoveOldTrashItems = true;
      ShowExternalHardDrivesOnDesktop = true;
      ShowHardDrivesOnDesktop = false;
      ShowRemovableMediaOnDesktop = true;
    };

    menuExtraClock = {
      ShowAMPM = true;
      ShowDate = 0;
      ShowDayOfWeek = true;
    };

    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
      TrackpadFourFingerHorizSwipeGesture = 2;
      TrackpadFourFingerVertSwipeGesture = 2;
      TrackpadMomentumScroll = true;
      TrackpadPinch = true;
      TrackpadRotate = true;
      TrackpadThreeFingerHorizSwipeGesture = 2;
      TrackpadThreeFingerVertSwipeGesture = 2;
      TrackpadTwoFingerFromRightEdgeSwipeGesture = 3;
    };
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  programs.zsh.enable = true;
}
