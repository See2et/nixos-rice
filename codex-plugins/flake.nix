{
  description = "Codex plugin sources updated together through the parent codex-plugins input";

  # Only the parent flake.lock owns source pins, as with the skills input.
  outputs =
    { ... }:
    {
      marketplaces = { };
    };
}
