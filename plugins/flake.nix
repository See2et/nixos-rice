{
  description = "Codex plugin sources updated together through the parent plugins input";

  inputs.astraeus = {
    url = "git+ssh://git@github.com/See2et/astraeus.git";
    flake = false;
  };

  # Only the parent flake.lock owns source pins, as with the skills input.
  outputs = { astraeus, ... }: {
    marketplaces.astraeus = {
      source = astraeus;
      plugins = [ "astraeus" ];
    };
  };
}
