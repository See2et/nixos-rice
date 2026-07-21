{ pkgs, inputs, ... }:

let
  compatPkgs = import inputs.nixpkgs-compat {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in

{
  # Desktop-only Unity/VRChat runtime compatibility layer.
  # GUARDRAIL: Do not import this module from common or WSL hosts.
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    openssl
    icu
    libGL
    libx11
    libxcursor
    libxrandr
    libxi
    libxrender
    libxfixes
    libxcomposite
    libxdamage
    libxcb
    libxtst
    libxscrnsaver
    udev
    gtk3
    glib
    gdk-pixbuf
    libxkbcommon
    libdrm
    mesa_glu
    dbus
    nss
    nspr
    expat
    fontconfig
    freetype
    alsa-lib
    libpulseaudio
    # Unity 2022.x still links against libxml2.so.2, unavailable on nixos-25.11.
    compatPkgs.libxml2.out
  ];
}
