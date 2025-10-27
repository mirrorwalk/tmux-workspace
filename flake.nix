{
  description = "Flake for tmux-workspace";

  outputs = {...}: {
    default = {
      imports = [
        ./tmux-workspace.nix
      ];
    };
  };
}
