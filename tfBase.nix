{ lib, config, ... }:
let
  inherit (lib.options) mkOption literalExpression;
  inherit (lib.types)
    deferredModule
    submodule
    attrsOf
    functionTo
    package
    unspecified
    ;
  inherit (lib.attrsets)
    mapAttrsToList
    ;

  tfMetaModule =
    { config, ... }:
    {
      options = {
        package = mkOption {
          type = functionTo package;
          defaultText = literalExpression "pkgs: pkgs.terraform";
          example = literalExpression "pkgs: pkgs.opentofu";
          default = pkgs: pkgs.terraform;
          description = "The package used for terraform";
        };
        finalPackage = mkOption {
          type = functionTo package;
          internal = true;
          description = "The terraform package with embedded lockfile and plugin paths";
        };
        data = mkOption {
          type = submodule {
            freeformType = unspecified;
          };
        };
        providers = mkOption {
          type = attrsOf (submodule {
            freeformType = unspecified;
            options.package = mkOption {
              type = functionTo package;
              example = literalExpression "p: p.camptocamp_pass";
              description = "The package used for terraform provider";
            };
          });
          example = literalExpression ''
            {
              aws = {
                package = p: p.hashicorp_aws;
                default = {
                  region = "us-east-1";
                };
                west = {
                  region = "us-west-1";
                };
              };
            }
          '';
          description = ''
            Used providers map, provider name to provider definition. '

            Provider definition consists from provider `package`, and any
            amount of provider aliases. For default alias use `default` name.
          '';
        };
      };
      config.finalPackage =
        pkgs:
        pkgs.terraform-locked.override {
          terraform = config.package pkgs;
          providers = p: mapAttrsToList (_: pr: pr.package p) config.providers;
        };
    };

  fakeTypes =
    { lib, ... }:
    {

    };
in
{
  options.tf = mkOption {
    type = deferredModule;
    apply =
      module:
      let
        res = lib.evalModules {
          modules = [
            module
            tfMetaModule
          ];
        };
      in
      res; # // { uncheckedConfig = (res.extendModules { modules = [ fakeTypes ]; }).config; };
  };
  config = {
    flake.tf = config.tf.config;
    perSystem =
      {
        pkgs,
        lib,
        self',
        ...
      }:
      let
        terraform = config.tf.config.finalPackage pkgs;
      in
      {
        packages.tf-doc = pkgs.runCommand "tf-options-doc.md" { } ''
          cat ${
            (pkgs.nixosOptionsDoc {
              inherit (config.tf) options;
              documentType = "none";
              warningsAreErrors = false;
            }).optionsCommonMark
          } >> $out
        '';
        packages.tf-json = pkgs.writeTextFile {
          name = "tf.json";
          text = builtins.toJSON ((import ./processTf.nix lib pkgs) config.tf.config);
        };
        packages.tf-functions-json = self'.packages.terraform-functions.override {

        };
        packages.terraform = terraform;
      };
  };
}
