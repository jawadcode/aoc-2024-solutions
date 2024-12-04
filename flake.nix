{
  description = "Advent of Code 2024 solutions in various languages";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    opam-nix.url = "github:tweag/opam-nix";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "opam-nix/nixpkgs";
    };
    crane.url = "github:ipetkov/crane";
    nixpkgs.follows = "opam-nix/nixpkgs";
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs,
    opam-nix,
    rust-overlay,
    crane,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        overlays = [(import rust-overlay)];
        pkgs = import nixpkgs {inherit system overlays;};

        craneLib =
          (crane.mkLib pkgs)
          .overrideToolchain
          (pkgs.rust-bin.stable.latest.default.override
            {extensions = ["rust-src" "rust-analyzer"];});
        commonArgs = {
          src = craneLib.cleanCargoSource ./rust-solutions;
          strictDeps = true;
          nativeBuildInputs = [];
          buildInputs = [];
        };
        rust-solutions-crate = craneLib.buildPackage (commonArgs
          // {
            cargoArtifacts = craneLib.buildDepsOnly commonArgs;
          });

        ocaml = let
          onLib = opam-nix.lib.${system};
          projPkgsQuery =
            builtins.mapAttrs (_: pkgs.lib.last)
            (onLib.listRepo (onLib.makeOpamRepo ./ocaml_solutions));
          devPkgsQuery = {
            ocaml-base-compiler = "*";
            ocaml-lsp-server = "*";
            ocamlformat = "*";
          };
          scope = onLib.buildOpamProject' {} ./ocaml_solutions devPkgsQuery;
        in {
          devPkgs = builtins.attrValues (pkgs.lib.getAttrs (builtins.attrNames devPkgsQuery) scope);
          pkg = (pkgs.lib.getAttrs (builtins.attrNames projPkgsQuery) scope).ocaml_solutions;
        };

        haskellPkg = let
          haskellPackages = pkgs.haskellPackages;
          packageName = "haskell-solutions";
        in
          haskellPackages.callCabal2nix packageName ./haskell-solutions {};
      in {
        packages = {
          rust-solutions = rust-solutions-crate;
          ocaml_solutions = ocaml.pkg;
          haskell-solutions = haskellPkg;
        };
        apps = builtins.mapAttrs (name: drv: flake-utils.lib.mkApp {drv = drv;}) self.packages.${system};
        devShells = {
          rust-solutions = craneLib.devShell {
            packages = [pkgs.taplo];
          };
          ocaml_solutions = pkgs.mkShell {
            inputsFrom = [ocaml.pkg];
            buildInputs = ocaml.devPkgs;
          };
          haskell-solutions = pkgs.mkShell {
            inputsFrom = [haskellPkg];
            buildInputs = with pkgs; [
              haskellPackages.haskell-language-server
              cabal-install
            ];
          };
        };
      }
    );
}
