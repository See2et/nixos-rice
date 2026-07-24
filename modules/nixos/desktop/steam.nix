{
  lib,
  pkgs,
  ...
}:

let
  isX86_64 = pkgs.stdenv.hostPlatform.isx86_64;
  steamFfmpegOverlay =
    _final: prev:
    let
      patchedFfmpegHeadless = prev.ffmpeg-headless.overrideAttrs (oldAttrs: {
        patches = (oldAttrs.patches or [ ]) ++ [
          ../../../home/desktop/vr/patches/ffmpeg-8.0-vulkan-cuda-packed-format.patch
        ];
      });
      patchedChromaprint = prev.chromaprint.override {
        ffmpeg-headless = patchedFfmpegHeadless;
      };
      patchedGstPluginsBad = prev.gst_all_1.gst-plugins-bad.override {
        chromaprint = patchedChromaprint;
      };
    in
    {
      nvidia-vaapi-driver = prev.nvidia-vaapi-driver.override {
        gst_all_1 = prev.gst_all_1 // {
          gst-plugins-bad = patchedGstPluginsBad;
        };
      };
    };
in

{
  nixpkgs.overlays = [ steamFfmpegOverlay ];

  programs.steam = lib.mkIf isX86_64 {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };
}
