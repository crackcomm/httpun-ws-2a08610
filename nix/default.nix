{ pkgs, nix-filter }:

let inherit (pkgs) ocamlPackages;

in with ocamlPackages;
buildDunePackage {
  pname = "ocxmr";
  version = "0.0.0-dev";

  src = with nix-filter.lib;
    filter {
      root = ./..;
      include = [ "dune-project" ];
      exclude = [ ];
    };

  propagatedBuildInputs = [
    core
    digestif
    dune-configurator
    eio
    eio-ssl
    eio_main
    h2
    h2-eio
    httpun-ws-eio
    shell
    uri
    ppx_yojson_conv
  ];
}
