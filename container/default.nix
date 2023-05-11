{ pkgs, nixpkgs, ... }:

let
  base = pkgs.callPackage ./base.nix { inherit nixpkgs; };
in
pkgs.dockerTools.buildImage {
  name = "coder-image";
  tag = "latest";
  fromImage = base;

  config = {
    Cmd = [ "/bin/fish" "--login" ];
    User = "coder";
  };
}
