{
  lib,
  pkgs,
  inputs,
  ...
}:

let
  isX86_64 = pkgs.stdenv.hostPlatform.isx86_64;
  steamPkgs = import inputs.nixpkgs-steam {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in

{
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Tokyo";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      fcitx5-skk
    ];
    fcitx5.settings.addons.skk = {
      globalSection = {
        InitialInputMode = "Latin";
      };
    };
  };

  console.useXkbConfig = true;
  services.xserver.xkb.layout = "jp";

  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings.main = {
        capslock = "layer(control)";
        "C-h" = "backspace";
      };
      settings.control = {
        h = "backspace";
      };
    };
  };

  users.users.see2et = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "networkmanager"
      "realtime"
      "video"
      "input"
    ];
  };

  programs.firefox.enable = true;

  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "see2et" ];
  };

  programs.steam = lib.mkIf isX86_64 {
    enable = true;
    package = steamPkgs.steam;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  hardware.steam-hardware.enable = lib.mkIf isX86_64 true;
  security.polkit.enable = true;

  programs.xfconf.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    neovim
    git
    wget
    alacritty
    fuzzel
    waybar
    swaybg
    wl-clipboard
    wl-clipboard-x11
    xdg-desktop-portal-gnome
    xdg-desktop-portal-gtk
    xwayland-satellite
    skkDictionaries.l
    skkDictionaries.jinmei
    skkDictionaries.geo
    (ffmpeg-full.override { withUnfree = true; })
    vulkan-tools
    libva-utils
  ];

  services.pcscd.enable = true;
  services.udev.enable = true;
  services.udev.packages = [ pkgs.yubikey-personalization ];

  system.stateVersion = "25.11";
}
