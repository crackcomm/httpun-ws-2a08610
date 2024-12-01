{ ocaml-ng, fetchFromGitHub }:

let ocamlPackages = ocaml-ng.ocamlPackages_5_2;
in let
  repos = {
    h2 = fetchFromGitHub {
      owner = "anmonteiro";
      repo = "ocaml-h2";
      rev = "49c0591";
      sha256 = "sha256-KVIYVF8q2umUPfWriRoGSg5vRtHp78GKhR+UPdM7Ro4=";
    };
    httpun-ws = fetchFromGitHub {
      owner = "anmonteiro";
      # owner = "crackcomm";
      repo = "httpun-ws";

      # OK:
      # rev = "1c05642dc29b30b1d36b5f8dba3fb139ce0cac69";
      # sha256 = "sha256-fCe4vdqYdl9HDjmlbdGQ83G35voGc2ruMOcbVQvgv4Y=";

      rev = "2a0861052a238a654fd69372c628a56a3e959339";
      sha256 = "sha256-WLFay3Wwq5hKDf8suivGdHnMva5pDAEFWWEa6oeGRp8=";

      # rev = "cde81ed";
      # sha256 = "sha256-oXnpVH25zEZzOg7kPyey4Wai6UHEkUpM2AQ5FSVTVp0=";

      # rev = "1c01080";
      # sha256 = "sha256-Wx3/A4JGUG9YIC091zzW2K2vjJZpiJY+tm5FhUFST1Q=";
    };
  };

in ocamlPackages.overrideScope (_: super:
  let
    makePkg = name: repo: buildInputs:
      super.buildDunePackage {
        name = name;
        pname = name;
        version = "dev";
        src = repo;
        propagatedBuildInputs = buildInputs;
      };
  in rec {
    httpun-ws = super.httpun-ws.overrideAttrs (oldAttrs: {
      version = "dev";
      src = repos.httpun-ws;
    });
    httpun-ws-eio = super.httpun-ws-eio.overrideAttrs (oldAttrs: {
      version = "dev";
      src = repos.httpun-ws;
    });

    hpack = super.hpack.overrideAttrs (oldAttrs: {
      pname = "hpack";
      version = "dev";
      src = repos.h2;
    });
    h2 = super.h2.overrideAttrs (oldAttrs: {
      version = "dev";
      src = repos.h2;
    });
    h2-eio = makePkg "h2-eio" repos.h2 [ h2 super.gluten-eio ];
  })
