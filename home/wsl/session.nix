# WSL-specific session variables and PATH
# Adds Windows VS Code bin directory to PATH
# CRITICAL: Only for WSL, must NOT appear in desktop or darwin
{ ... }:
{
  home.sessionPath = [
    "/mnt/c/Users/See2et/AppData/Local/Programs/Microsoft VS Code/bin"
  ];
}
