{ pkgs, ocxmr }:

with pkgs;
with ocamlPackages;
mkShell {
  inputsFrom = [ ocxmr ];
  packages = [
    nixfmt-classic
    ocaml
    dune_3
    # language server
    ocaml-lsp
    # formatter
    ocamlformat
  ];
}
