#.drivers  Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
    useOSProber = true;
    configurationLimit = 10;
    # efiInstallAsRemovable = true;
  };

  # networking.hostName = "nixos"; # Define your hosname.

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Tokyo";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
  ];

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;

    fcitx5.waylandFrontend = true;

    fcitx5.addons = with pkgs; [
      fcitx5-skk
    ];
  };
  console = {
    useXkbConfig = true; # use xkb.options in tty.
  };
  # Enable the X11 windowing system.
  # services.xserver.enable = true;
  # Configure keymap in X11
  services.xserver.xkb.layout = "jp";
  # services.xserver.xkb.options = "caps:ctrl_modifier";
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings.main = {
        capslock = "layer(control)";
      };
    };
  };

  # services.greetd = {
  #   enable = false;
  #   settings = rec {
  #     initial_session = {
  #       command = "${pkgs.niri}/bin/niri--session";
  #       user = "see2et";
  #     };
  #     default_session = initial_session;
  #   };
  # };
  services.displayManager = {
    gdm.enable = true;
    defaultSession = "niri";
    sessionPackages = [ pkgs.niri ];
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  services.pulseaudio.enable = false;
  # OR
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    jack.enable = true;

    extraConfig = {
      pipewire."99-disable-x11-bell.conf" = {
        "context.properties" = {
	  "module.x11.bell" = false;
	};
      };
    };
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.see2et = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "networkmanager"
      "realtime"
      "video"
      "input"
    ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
    ];
  };

  home-manager.extraSpecialArgs = { inherit inputs; };

  nixpkgs.config.allowUnfree = true;

  programs.zsh.enable = true;
  programs.firefox.enable = true;
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "see2et" ];
  };
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    package = pkgs.steam.override {
      extraPkgs = pkgs': with pkgs'; [ 
        SDL2 
        openvr
        libsForQt5.qt5.qtbase
        libsForQt5.qt5.qtmultimedia
	mpg123

	pipewire
	wireplumber
	libpulseaudio
	pavucontrol
	helvum	
      ];
    };
  };
  hardware.steam-hardware.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  environment.sessionVariables = {
    VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json";
    VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json";
  };
  hardware.graphics = { 
    enable32Bit = true;
    extraPackages32 = with pkgs.pkgsi686Linux; [ mesa ];
  };
  security.polkit.enable = true;
  security.rtkit.enable = true;
  security.pam.loginLimits = [
    {
      domain = "@realtime";
      type = "-";
      item = "rtprio";
      value = "98";
    }
    {
      domain = "@realtime";
      type = "-";
      item = "nice";
      value = "-20";
    }
    {
      domain = "@realtime";
      type = "-";
      item = "memlock";
      value = "unlimited";
    }
  ];
  systemd.user.extraConfig = ''
    [Manager]
    DefaultLimitRTPRIO=98
    DefaultLimitNICE=-20
    DefaultLimitMEMLOCK=infinity
  '';
  services.wivrn = {
    enable = true;
    openFirewall = true;
    defaultRuntime = true;
    autoStart = true;
  };
  services.avahi.enable = true;
  services.avahi.nssmdns4 = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
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

    (steam.override {extraPkgs = pkgs': with pkgs'; [ 
      SDL2 
      openvr
      libsForQt5.qt5.qtbase
      libsForQt5.qt5.qtmultimedia
      mpg123
      pipewire
      wireplumber
      libpulseaudio
      pavucontrol
      helvum	
    ];}).run
    (ffmpeg-full.override { withUnfree = true; })
    vulkan-tools
    libva-utils
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # around USB
  services.pcscd.enable = true;
  services.udev.packages = [ pkgs.yubikey-personalization ];
  services.udev.enable = true;

  programs.niri.enable = true;
  programs.niri.package = pkgs.niri;
  xdg.portal.enable = true;
  xdg.portal.xdgOpenUsePortal = true;

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  networking.firewall = {
    enable = true;
    # 9943 and 9944 for ALVR
    allowedTCPPorts = [
      9943
      9944
    ];
    allowedUDPPorts = [
      9943
      9944
    ];
  };
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}
