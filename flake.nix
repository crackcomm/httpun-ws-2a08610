{
  description = "Nix Flake";

  inputs = {
    nixpkgs.url = "github:anmonteiro/nix-overlays";
    nix-filter.url = "github:numtide/nix-filter";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nix-filter, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = (nixpkgs.makePkgs { inherit system; }).extend (self: super: {
          ocamlPackages = import ./nix/ocaml.nix {
            inherit (super) ocaml-ng fetchFromGitHub;
          };
        });
      in let ocxmr = pkgs.callPackage ./nix { inherit nix-filter; };
      in let
        docpkgs = pkgs.buildEnv {
          name = "docpkgs";
          paths = ocxmr.propagatedBuildInputs;
        };
      in {
        packages = { inherit ocxmr docpkgs; };
        devShell = import ./nix/shell.nix { inherit pkgs ocxmr; };
      });
}
