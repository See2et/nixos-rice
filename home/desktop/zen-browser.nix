{ inputs, ... }:
{
  imports = [
    inputs.zen-browser.homeModules.beta
  ];

  programs.zen-browser = {
    enable = true;

    profiles.default = {
      id = 0;
      path = "default";
      isDefault = true;
      settings = {
        "app.normandy.first_run" = false;
        "browser.aboutwelcome.enabled" = false;
        "browser.startup.firstrunSkipsHomepage" = true;
        "browser.startup.homepage_override.mstone" = "ignore";
        "trailhead.firstrun.didSeeAboutWelcome" = true;
        "zen.welcome-screen.seen" = true;
      };
    };
  };

}
