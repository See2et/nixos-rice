# Darwin-specific Home Manager modules
# Settings ONLY for macOS/Darwin: Darwin-specific aliases, env vars, packages
# CRITICAL: No Linux-specific paths or tools
# Task 12: Darwin Home Manager Preservation

{ config, pkgs, inputs, isDarwin ? false, lib, ... }:
{
  # Darwin-specific overrides and settings
  # These settings are applied ONLY when isDarwin = true

  # Ensure isDarwin is true for this module (safety check)
  assertions = [
    {
      assertion = isDarwin;
      message = "home/darwin module should only be imported when isDarwin = true";
    }
  ];

  # Darwin-specific environment variables (if needed in future)
  # home.sessionVariables = { };

  # Darwin-specific packages (if needed in future)
  # home.packages = with pkgs; [ ];

  # Darwin-specific program configurations can be added here
  # Example: macOS-specific shell settings, tools, etc.
}
