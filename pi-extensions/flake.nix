# Generated body SHA256: d26dedb053fb1f28f6f58cdb2a0abe9879e3d2279d4fe9c102542befe93eb839
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
    pi-understanding = {
      url = "git+ssh://git@github.com/See2et/pi-understanding.git";
      flake = false;
    };
  };

  # Never create a child flake.lock: the parent owns all revisions.
  outputs = { ... }: { };
}
