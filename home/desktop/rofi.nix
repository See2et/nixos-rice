{ config, ... }:
let
  t = config.desktop.ui.tokens;
in
{
  xdg.configFile = {
    "rofi/config.rasi".text = ''
      @theme "niri-archcraft-cyan"
    '';

    "rofi/themes/niri-archcraft-cyan.rasi".text = ''
      * {
          background:                  ${t.colors.background};
          surface:                     ${t.colors.surface};
          foreground:                  ${t.colors.foreground};
          muted:                       ${t.colors.muted};
          border-col:                  ${t.colors.border};
          accent:                      ${t.colors.accent};
          urgent:                      ${t.colors.danger};
          active:                      ${t.colors.success};

          normal-background:           var(surface);
          normal-foreground:           var(foreground);
          alternate-normal-background: var(surface);
          alternate-normal-foreground: var(foreground);
          urgent-background:           var(surface);
          urgent-foreground:           var(urgent);
          active-background:           var(surface);
          active-foreground:           var(active);
          selected-normal-background:  var(accent);
          selected-normal-foreground:  var(background);
          selected-urgent-background:  var(urgent);
          selected-urgent-foreground:  #ffffff;
          selected-active-background:  var(active);
          selected-active-foreground:  #ffffff;

          border-color:                var(border-col);
          separatorcolor:              var(border-col);
          background-color:            transparent;
          spacing:                     ${toString t.spacing.lg}px;
      }

      window {
          width:            38%;
          padding:          ${toString t.spacing.xxxl}px;
          border:           1px;
          border-color:     var(border-col);
          border-radius:    ${toString t.radii.md}px;
          background-color: var(background);
      }

      mainbox {
          spacing: ${toString t.spacing.lg}px;
      }

      inputbar {
          padding:          ${toString t.spacing.xl}px ${toString t.spacing.xxxl}px;
          spacing:          ${toString t.spacing.lg}px;
          border:           1px;
          border-color:     var(border-col);
          border-radius:    ${toString t.radii.sm}px;
          background-color: var(surface);
          children:         [ "prompt", "entry" ];
      }

      prompt {
          str:        "Search";
          text-color: var(accent);
      }

      entry {
          text-color:        var(foreground);
          placeholder:       "Applications";
          placeholder-color: var(muted);
      }

      listview {
          columns:       1;
          lines:         10;
          spacing:       ${toString t.spacing.md}px;
          border:        0;
          scrollbar:     true;
          fixed-height:  false;
          background-color: transparent;
      }

      element {
          padding:          ${toString t.spacing.xl}px ${toString t.spacing.xxl}px;
          spacing:          ${toString t.spacing.lg}px;
          border:           1px;
          border-color:     var(border-col);
          border-radius:    ${toString t.radii.sm}px;
          background-color: var(surface);
          text-color:       var(foreground);
          children:         [ "element-icon", "element-text" ];
      }

      element normal.normal {
          background-color: var(normal-background);
          text-color:       var(normal-foreground);
      }

      element normal.urgent {
          background-color: var(urgent-background);
          text-color:       var(urgent-foreground);
      }

      element normal.active {
          background-color: var(active-background);
          text-color:       var(active-foreground);
      }

      element selected.normal {
          background-color: var(selected-normal-background);
          text-color:       var(selected-normal-foreground);
      }

      element selected.urgent {
          background-color: var(selected-urgent-background);
          text-color:       var(selected-urgent-foreground);
      }

      element selected.active {
          background-color: var(selected-active-background);
          text-color:       var(selected-active-foreground);
      }

      element-text {
          background-color: transparent;
          text-color:       inherit;
      }

      element-icon {
          background-color: transparent;
          text-color:       inherit;
          size:             1em;
      }

      scrollbar {
          width:            6px;
          handle-width:     6px;
          border:           0;
          background-color: ${t.colors.background};
          handle-color:     ${t.colors.muted};
      }
    '';
  };
}
