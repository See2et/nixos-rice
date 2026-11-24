# Generated body SHA256: c11923742049171062925807b8b07ef643f724b3692e9be1dd9084018b983162
{
  # Generated from inventory.json by update.py; do not register inputs here.
  description = "Pi extension Git sources (pins live in the root flake.lock)";

  inputs = {
    pi-subagents = {
      url = "github:tintinweb/pi-subagents";
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
