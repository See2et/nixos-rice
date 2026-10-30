# Generated body SHA256: c543e35da4726bb4ab09c5cf22690fae8aa1bc364b58b6236c082b1a65588fe9
{
  # Generated from inventory.json by update.py; do not register inputs here.
  description = "Pi extension Git sources (pins live in the root flake.lock)";

  inputs = {
    pi-subagents = {
      url = "github:tintinweb/pi-subagents";
      flake = false;
    };
    pi-astraeus = {
      url = "git+ssh://git@github.com/See2et/pi-astraeus.git";
      flake = false;
    };
    pi-mentor = {
      url = "git+ssh://git@github.com/See2et/pi-mentor.git";
      flake = false;
    };
  };

  # Never create a child flake.lock: the parent owns all revisions.
  outputs = { ... }: { };
}
