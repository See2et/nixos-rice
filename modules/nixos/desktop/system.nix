{ pkgs, inputs, ... }:

let
  steamPkgs = import inputs.nixpkgs-steam {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in

{
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Tokyo";

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    texlivePackages.haranoaji
    source-han-sans
    source-han-serif
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];

  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      serif = [
        "Harano Aji Mincho"
        "Noto Serif CJK JP"
        "Noto Color Emoji"
        "serif"
      ];
      sansSerif = [
        "Harano Aji Gothic"
        "FiraCode Nerd Font"
        "Noto Sans CJK JP"
        "Noto Sans CJK KR"
        "Noto Sans CJK SC"
        "Noto Color Emoji"
        "sans-serif"
      ];
      monospace = [
        "FiraCode Nerd Font"
        "Harano Aji Gothic"
        "Noto Sans CJK JP"
        "Noto Color Emoji"
        "monospace"
      ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

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

  programs.steam = {
    enable = true;
    package = steamPkgs.steam;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  hardware.steam-hardware.enable = true;
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
