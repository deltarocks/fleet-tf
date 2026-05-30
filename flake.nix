{
  description = "Fleet terraform integration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-26.05";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    shelly.url = "github:CertainLach/shelly";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (
      { self, ... }:
      let
        mkTerraformModule = file: import ./tf.nix (builtins.fromJSON (builtins.readFile file));
      in
      {
        imports = [
          inputs.shelly.flakeModule
          ./tfBase.nix
          # (mkTerraformModule ./providers.json)
        ];
        systems = inputs.nixpkgs.lib.systems.flakeExposed;

        flake.mkFlakeModules.terraform = mkTerraformModule;
        flake.lib.mkFunctions =
          file: import ./function.nix inputs.nixpkgs.lib (builtins.fromJSON (builtins.readFile file));
        flake.lib.nixpkgsLib = inputs.nixpkgs.lib;

        flake.overlays.default = pkgs: prev: {
          terraform-calculator = pkgs.callPackage ./nix/terraform-calculator.nix { };
          terraform-lockfile = pkgs.callPackage ./nix/lockfile.nix {
            inherit (pkgs) terraform-calculator;
          };
          terraform-locked = pkgs.callPackage ./nix/terraform-locked.nix {
            inherit (pkgs) terraform-lockfile;
          };
          terraform-functions-json = pkgs.callPackage ./nix/terraform-functions.nix { };
          terraform-providers-json = pkgs.callPackage ./nix/terraform-providers.nix {
            inherit (pkgs) terraform-locked;
          };
        };

        tf =
          { config, ... }:
          {
            providers.pass = {
              package = p: p.camptocamp_pass;
              default = { };
            };
          };

        perSystem =
          {
            self',
            lib,
            pkgs,
            system,
            ...
          }:
          {
            _module.args.pkgs = import inputs.nixpkgs {
              inherit system;
              # Defaulting to terraform, due to dumb opentofu registry policy restricting
              # access from certain contries.
              config.allowUnfreePredicate = pkg: lib.getName pkg == "terraform";

              overlays = [ self.overlays.default ];
            };

            packages = {
              inherit (pkgs)
                terraform-calculator
                terraform-lockfile
                terraform-locked
                terraform-functions-json
                terraform-providers-json
                ;
            };

            shelly.shells.default = {
              packages = with pkgs; [
                jq
              ];

              environment.NIX_FMT = lib.getExe self'.formatter;
            };

            formatter = pkgs.alejandra;
          };
      }
    );
}
