{
  description = "Skill sources updated together through the parent skills input";

  inputs = {
    personal-skills = {
      # Fetch as the invoking user (before sudo), using their SSH configuration.
      url = "git+ssh://git@github.com/See2et/agent-skills.git";
      flake = false;
    };
    yomiyasu = {
      url = "github:nanaism/yomiyasu";
      flake = false;
    };
  };

  # Intentionally no child flake.lock: /etc/nixos/flake.lock owns these pins.
  # A child lock would make the parent update honor its pins instead of HEAD.
  outputs = { ... }: { };
}
