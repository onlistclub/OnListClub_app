{
  description = "Ambiente di sviluppo e test per OnListClub_app (Flutter)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          # Pacchetti disponibili in questo ambiente isolato
          buildInputs = with pkgs; [
            flutter
            # Puoi decommentare queste righe se ti servono tool aggiuntivi per Android
            # android-tools
            # jdk17
          ];

          shellHook = ''
            echo "========================================="
            echo "Ambiente Nix per OnListClub_app attivato!"
            echo "========================================="
            flutter --version
          '';
        };
      }
    );
}