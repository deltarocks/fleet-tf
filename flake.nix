{
  description = "Fleet terraform integration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-24.11";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    shelly.url = "github:CertainLach/shelly";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.shelly.flakeModule
      ];
      systems = inputs.nixpkgs.lib.systems.flakeExposed;

      flake.mkFlakeModules.terraform = file: (builtins.fromJSON (builtins.readFile file));
      flake.lib.mkFunctions = file: import ./function.nix inputs.nixpkgs.lib (builtins.fromJSON (builtins.readFile file));
      flake.lib.nixpkgsLib = inputs.nixpkgs.lib;

      perSystem = {
        self',
        lib,
        pkgs,
        system,
        ...
      }: {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          # Defaulting to terraform, due to dumb opentofu registry policy restricting
          # access from certain contries.
          config.allowUnfreePredicate = pkg: lib.getName pkg == "terraform";
        };

        packages = {
          terraform-calculator = pkgs.callPackage ./nix/terraform-calculator.nix {};
          terraform-lockfile = pkgs.callPackage ./nix/lockfile.nix {
            inherit (self'.packages) terraform-calculator;
          };
          terraform-locked = pkgs.callPackage ./nix/terraform-locked.nix {
            inherit (self'.packages) terraform-lockfile;
            providers = p: [p.pass];
          };
          terraform-functions = pkgs.callPackage ./nix/terraform-functions.nix {};
          terraform-providers = pkgs.callPackage ./nix/terraform-providers.nix {
            inherit (self'.packages) terraform-locked;
          };
        };

        shelly.shells.default = {
          packages = with pkgs; [
            jq
            (self'.packages.terraform-locked.override {providers = p: [p.pass];})
          ];

          environment.NIX_FMT = lib.getExe self'.formatter;
        };

        formatter = pkgs.alejandra;
      };
    };
}
