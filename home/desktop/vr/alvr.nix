{
  lib,
  pkgs,
  ...
}:
let
  isX86_64 = pkgs.stdenv.hostPlatform.isx86_64;
  ffmpegPackedFormatAlvrPatch = builtins.toFile "ffmpeg-8.0-vulkan-cuda-packed-format-alvr.patch" ''
    From 927f205eb8de44fc106a36f00ea9d713c813a4f3 Mon Sep 17 00:00:00 2001
    From: FFmpeg upstream
    Date: Mon, 20 Jul 2026 00:00:00 +0000
    Subject: [PATCH] avutil/hwcontext_vulkan: fix CUDA packed-format channel count

    Backport follow-up for ALVR's ffmpeg tree, which already carries
    0001-lavu-hwcontext_vulkan-Fix-importing-RGBx-frames-to-C.patch.

    ---
     libavutil/hwcontext_vulkan.c | 3 ++-
     1 file changed, 2 insertions(+), 1 deletion(-)

    diff --git a/libavutil/hwcontext_vulkan.c b/libavutil/hwcontext_vulkan.c
    index e3bd6ace9b..f87cb8b7dc 100644
    --- a/libavutil/hwcontext_vulkan.c
    +++ b/libavutil/hwcontext_vulkan.c
    @@ -3761,6 +3761,7 @@ static int vulkan_export_to_cuda(AVHWFramesContext *hwfc,
         CudaFunctions *cu = cu_internal->cuda_dl;
         CUarray_format cufmt = desc->comp[0].depth > 8 ? CU_AD_FORMAT_UNSIGNED_INT16 :
                                                          CU_AD_FORMAT_UNSIGNED_INT8;
    +    const int elem_size = 1 + (desc->comp[0].depth > 8);

         dst_f = (AVVkFrame *)frame->data[0];
         dst_int = dst_f->internal;
    @@ -3805,7 +3806,7 @@ static int vulkan_export_to_cuda(AVHWFramesContext *hwfc,
                         .Depth = 0,
                         .Format = cufmt,
    -                    .NumChannels = desc->comp[i].step,
    +                    .NumChannels = desc->comp[i].step / elem_size,
                         .Flags = 0,
                     },
                     .numLevels = 1,
  '';
  patchedFfmpegAlvr = pkgs.alvr.passthru."ffmpeg-alvr".overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      ffmpegPackedFormatAlvrPatch
    ];
  });
  alvr =
    (pkgs.alvr.override {
      "ffmpeg-alvr" = patchedFfmpegAlvr;
    }).overrideAttrs
      (oldAttrs: {
        postPatch = (oldAttrs.postPatch or "") + ''
          substituteInPlace alvr/server_openvr/src/lib.rs --replace-fail \
            'let early_hmd_initialization = !dashboard_processes.is_empty();' \
            'let early_hmd_initialization = true;'
        '';
      });

  alvrEnvText = ''
    if [ -n "''${WAYLAND_DISPLAY:-}" ]; then
      export WINIT_UNIX_BACKEND=wayland
      if [ -n "''${DISPLAY:-}" ]; then
        display_num="''${DISPLAY#*:}"
        display_num="''${display_num%%.*}"
        if [ -z "$display_num" ] || [ ! -S "/tmp/.X11-unix/X$display_num" ]; then
          if [ -S "/tmp/.X11-unix/X0" ]; then
            export DISPLAY=":0"
          else
            unset DISPLAY
            unset XAUTHORITY
          fi
        fi
      elif [ -S "/tmp/.X11-unix/X0" ]; then
        export DISPLAY=":0"
      fi
    elif [ -n "''${DISPLAY:-}" ]; then
      display_num="''${DISPLAY#*:}"
      display_num="''${display_num%%.*}"

      if [ -n "$display_num" ] && [ ! -S "/tmp/.X11-unix/X$display_num" ]; then
        unset DISPLAY
        unset XAUTHORITY
      fi
    fi
  '';

  alvrDashboard = pkgs.writeShellApplication {
    name = "alvr_dashboard";
    runtimeInputs = [ alvr ];
    text = ''
      ${alvrEnvText}
      exec "${alvr}/bin/alvr_dashboard" "$@"
    '';
  };

  alvrLauncher = pkgs.writeShellApplication {
    name = "alvr_launcher";
    runtimeInputs = [ alvr ];
    text = ''
      ${alvrEnvText}
      exec "${alvr}/bin/alvr_launcher" "$@"
    '';
  };
in
{
  home.packages = lib.optionals isX86_64 [
    alvrDashboard
    alvrLauncher
  ];

  xdg.desktopEntries.alvr = lib.mkIf isX86_64 {
    name = "ALVR";
    genericName = "Game";
    comment = "ALVR is an open source remote VR display which allows playing SteamVR games on a standalone headset such as Gear VR or Oculus Go/Quest.";
    exec = "alvr_dashboard";
    terminal = false;
    type = "Application";
    icon = "alvr";
    categories = [ "Game" ];
    startupNotify = true;
    settings = {
      StartupWMClass = "alvr.dashboard";
    };
  };

  xdg.desktopEntries.alvr-dashboard = lib.mkIf isX86_64 {
    name = "ALVR Dashboard";
    genericName = "VR streaming dashboard";
    exec = "alvr_dashboard";
    terminal = false;
    type = "Application";
    icon = "alvr";
    categories = [
      "Game"
      "Network"
    ];
    startupNotify = true;
  };
}
