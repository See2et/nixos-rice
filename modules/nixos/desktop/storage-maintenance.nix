{ ... }:

{
  # Generation retention is owned by hosts/desktop/*generation-retention.nix.
  # GC only removes unreferenced store paths; never delete profile generations here.
  nix.gc = {
    automatic = true;
    dates = "daily";
    persistent = true;
    options = "";
  };

  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };
}
