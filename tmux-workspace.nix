{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.shells.tmux.tmux-workspace;

  # Generate ROOT_FOLDERS bash declaration
  rootFoldersStr = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (path: value: ''ROOT_FOLDERS["${path}"]="${value}"'') cfg.rootFolders
  );

  # Generate CUSTOM_WINDOWS bash declaration
  customWindowsStr = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (path: value: ''CUSTOM_WINDOWS["${path}"]="${value}"'') cfg.customWindows
  );

  configFile = pkgs.writeText "tmux-workspace-config.sh" ''
    #!/bin/bash

    declare -A ROOT_FOLDERS
    ${rootFoldersStr}

    declare -A CUSTOM_WINDOWS
    ${customWindowsStr}
  '';

  tmux-workspace = pkgs.writeShellScriptBin "tmux-workspace" ''
    ${builtins.readFile ./tmux-workspace}
  '';
in {
  options.shells.tmux.tmux-workspace = {
    enable = lib.mkEnableOption "enable tmux-workspace";

    rootFolders = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Root folders to search for projects";
      example = lib.literalExpression ''
        {
          "''${config.home.homeDirectory}/projects" = "1:1";
          "''${config.home.homeDirectory}/.config" = "1:1";
        }
      '';
    };

    addToPackages = lib.mkEnableOption "Add tmux-workspace to home packages";

    customWindows = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Custom window configurations for specific projects";
      example = lib.literalExpression ''
        {
          "''${config.home.homeDirectory}/projects/myproject" = "code:terminal";
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zsh = lib.mkIf config.shells.zsh.enable {
      initExtra = ''
        bindkey -s '^x' "tmux-workspace\n"
      '';
    };

    programs.bash = lib.mkIf config.shells.bash.enable {
      initExtra = ''
        bind '"\C-x":"${tmux-workspace}/bin/tmux-workspace\n"'
      '';
    };

    home.packages = lib.mkIf cfg.addToPackages [tmux-workspace];

    home.file.".config/tmux-workspace/config.sh".source = configFile;
  };
}
