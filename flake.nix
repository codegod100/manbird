{
  description = "Build Ladybird from nixpkgs packaging, with GitHub Actions tracking upstream master";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
      ];
      forAllSystems = lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
        in
        rec {
          ladybird = pkgs.callPackage ./pkgs/ladybird/package.nix { };
          default = ladybird;
        }
      );
    };
}
