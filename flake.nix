{
  description = "Private NixOS configuration";

  outputs = {...}: {
    default = {
      imports = [
        ./tmux-workspace.nix
      ];
    };
  };
}
