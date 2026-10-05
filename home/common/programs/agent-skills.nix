{ inputs, lib, ... }:
{
  imports = [
    inputs.agent-skills-nix.homeManagerModules.default
    ./skills-audit
  ];

  programs.agent-skills = {
    enable = true;
    sources.personal = {
      path = inputs.skills.inputs.personal-skills.outPath;
      # Only discover top-level skills, not evaluation/comparison fixtures.
      filter.maxDepth = 1;
    };
    sources.yomiyasu = {
      path = inputs.skills.inputs.yomiyasu.outPath;
      # Use the packaged skill with its references/assets/scripts, not the root copy.
      subdir = "skills";
      filter.maxDepth = 1;
    };
    skills.enable = [ "yomiyasu" ];
    skills.enableAll = [ "personal" ];
    # Codex and OpenCode already discover this shared location.
    targets.agents = {
      enable = true;
      dest = ".agents/skills";
      structure = "link";
    };
  };

  # Own one immutable bundle link without forced replacement. These hosts allow
  # HM backup relocation; manually move the checkout before initial activation
  # to keep it in a development directory rather than skills.hm-backup.
  home.file.".agents/skills" = {
    recursive = lib.mkForce false;
    force = lib.mkForce false;
  };
}
