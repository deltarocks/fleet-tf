tfMeta: {
  lib,
  config,
  ...
}: let
  inherit (lib) last split;
  inherit (lib.options) mkOption;
  inherit (lib.types) deferredModule str submodule submoduleWith lazyAttrsOf mkOptionType oneOf;
  inherit (lib.attrsets) mapAttrs mapAttrs' filterAttrs optionalAttrs catAttrs attrValues;
  transformDoc = val:
    if !(val ? description)
    then null
    else if val.description_kind == "plain" || val.description_kind == "markdown"
    then (builtins.replaceStrings ["##"] ["\\#\\#"] val.description)
    else throw "unknown description kind: ${val.description_kind}";
  tfRef = ref: {
    _type = "tfRef";
    inherit ref;
    __functor = self: field: tfRef (ref ++ [field]);
    __toString = _: "::TF_REF::" + builtins.toJSON ref;
  };
  tfCall = fn: params: {
    _type = "tfCall";
    inherit fn params;
    __functor = self: field: tfRef [self field];
    __toString = _: "::TF_CALL::{" + fn + "}" + builtins.toJSON params;
  };
  tfRefTy = mkOptionType {
    name = "tfRef";
    check = ref:
      ref
      ? _type
      && (
        (ref._type == "tfRef" && ref ? ref)
        || (ref._type == "tfCall" && ref ? fn && ref ? params)
      );
  };
  isComputed = value:
    if value ? computed
    then value.computed
    else false;

  blockToType = ty: resource: schema:
    submodule ({config, ...}: {
      options = mapAttrs (attr: value:
        mkOption ({
            type = oneOf [str tfRefTy];
            description = transformDoc value;
            readOnly = isComputed value;
          }
          // optionalAttrs (isComputed value) {
            default = tfRef [ty resource config._module.args.name attr];
          }))
      schema.block.attributes;
      config = {};
    });

  providerToOptions = schemaType: let
    schemaTypeInternal =
      {
        data = "data_source_schemas";
        resource = "resource_schemas";
      }
      ."${schemaType}";
    ress = catAttrs schemaTypeInternal (attrValues tfMeta.provider_schemas);
  in
    mkOption {
      type = submoduleWith {
        modules =
          map (
            rm: {
              options =
                mapAttrs (
                  resource: s:
                    mkOption {
                      type = lazyAttrsOf (blockToType schemaType resource s);
                      description = transformDoc s.block;
                      default = {};
                    }
                )
                rm;
            }
          )
          ress;
      };
      default = {};
    };
  # mapAttrs' (_provider: schemas: let
  #   provider = last (split "/" _provider);
  # in {
  #   name = provider;
  #   value = mkOption {
  #     type = submodule {
  #       options = mapAttrs (resource: s:
  #       schemas;
  #       _file = "generated provider <${provider}>";
  #     };
  #     description = transformDoc schemas;
  #     default = {};
  #   };
  # })
  # perProvider;
in {
  options.tf = mkOption {
    type = deferredModule;
    apply = module:
      lib.evalModules {
        modules = [module];
      };
  };
  config = {
    flake.tf = config.tf;
    tf = {config, ...}: {
      options.data = providerToOptions "data";
      options.resource = providerToOptions "resource";
      config = {
        data.pass_password = {
          test = {
            path = "secret/foo";
          };
          test2 = {
            path = tfCall "concat" [(config.data.pass_password.test.data "key")];
          };
        };
      };
    };
    perSystem = {
      config,
      pkgs,
      lib,
      self',
      ...
    }: {
      packages.tf-doc = pkgs.runCommand "tf-options-doc.md" {} ''
        cat ${(pkgs.nixosOptionsDoc {
            inherit (config.tf) options;
            documentType = "none";
            warningsAreErrors = false;
          })
          .optionsCommonMark} >> $out
      '';
      packages.tf = pkgs.writeTextFile {
        name = "tf.json";
        text = builtins.toJSON ((import ./processTf.nix lib) config.tf.config);
      };
      packages.tftest = pkgs.writeTextFile {
        name = "tf.json";
        text = self'.legacyPackages.hashOfPackage pkgs.terraform-providers.time;
      };
    };
  };
  _file = ./tf.nix;
}
