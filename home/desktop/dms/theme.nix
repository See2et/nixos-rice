{ t }:
builtins.toJSON {
  dark = {
    name = "see2et Graphite Cyan";
    primary = t.colors.accent;
    primaryText = t.colors.background;
    primaryContainer = "#004d5c";
    secondary = t.colors.lavender;
    surface = t.colors.surface;
    surfaceText = t.colors.foreground;
    surfaceVariant = t.colors.surfaceElevated;
    surfaceVariantText = t.colors.foreground;
    surfaceTint = t.colors.accent;
    background = t.colors.background;
    backgroundText = t.colors.foreground;
    outline = t.colors.border;
    surfaceContainerLowest = t.colors.overlay;
    surfaceContainerLow = t.colors.background;
    surfaceContainer = t.colors.surface;
    surfaceContainerHigh = t.colors.surfaceElevated;
    surfaceContainerHighest = t.colors.border;
    error = t.colors.danger;
    warning = t.colors.warning;
    info = t.colors.info;
    matugen_type = "scheme-tonal-spot";
  };
  light = {
    name = "see2et Graphite Cyan Light";
    primary = "#008fb8";
    primaryText = "#ffffff";
    primaryContainer = "#b9e9f5";
    secondary = "#625ea8";
    surface = "#f5f7fa";
    surfaceText = "#1b1b1d";
    surfaceVariant = "#dde1e6";
    surfaceVariantText = "#444950";
    surfaceTint = "#008fb8";
    background = "#eef1f5";
    backgroundText = "#1b1b1d";
    outline = "#6a717b";
    surfaceContainerLowest = "#ffffff";
    surfaceContainerLow = "#f4f6f8";
    surfaceContainer = "#e8ebef";
    surfaceContainerHigh = "#dde1e6";
    surfaceContainerHighest = "#cfd4da";
    error = "#ba1a1a";
    warning = "#8a5a00";
    info = "#006878";
    matugen_type = "scheme-tonal-spot";
  };
}
