{
  description = "Personal nixos modules and packages";

  inputs = {
    nixpkgs.url = "github:5aaee9/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    nixld.url = "github:nix-community/nix-ld-rs";

  };

  outputs = { self, nixpkgs, flake-utils, nixld, ... }: flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ]
    (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            nixld.overlays.default
          ];
        };
      in
      {
        formatter = pkgs.nixpkgs-fmt;
        packages.container = import ./container { inherit pkgs nixpkgs; };
      });
}
