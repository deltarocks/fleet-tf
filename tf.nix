tfMeta:
{
  lib,
  config,
  ...
}:
let
  inherit (lib) last split;
  inherit (lib.options) mkOption;
  inherit (lib.types)
    deferredModule
    str
    submodule
    submoduleWith
    lazyAttrsOf
    mkOptionType
    oneOf
    attrsOf
    listOf
    functionTo
    package
    unspecified
    ;
  inherit (lib.attrsets)
    mapAttrs
    mapAttrs'
    filterAttrs
    optionalAttrs
    catAttrs
    attrValues
    mapAttrsToList
    ;
  transformDoc =
    val:
    if !(val ? description) then
      null
    else if val.description_kind == "plain" || val.description_kind == "markdown" then
      (builtins.replaceStrings [ "##" ] [ "\\#\\#" ] val.description)
    else
      throw "unknown description kind: ${val.description_kind}";
  tfRef = ref: {
    _type = "tfRef";
    inherit ref;
    __functor = self: field: tfRef (ref ++ [ field ]);
    __toString = _: "::TF_REF::" + builtins.toJSON ref;
  };
  tfCall = fn: params: {
    _type = "tfCall";
    inherit fn params;
    __functor =
      self: field:
      tfRef [
        self
        field
      ];
    __toString = _: "::TF_CALL::{" + fn + "}" + builtins.toJSON params;
  };
  tfRefTy = mkOptionType {
    name = "tfRef";
    check =
      ref:
      ref ? _type
      && ((ref._type == "tfRef" && ref ? ref) || (ref._type == "tfCall" && ref ? fn && ref ? params));
  };
  isComputed = value: if value ? computed then value.computed else false;

  blockToType =
    ty: resource: schema:
    submodule (
      { config, ... }:
      {
        options = mapAttrs (
          attr: value:
          mkOption (
            {
              type = oneOf [
                str
                tfRefTy
              ];
              description = transformDoc value;
              readOnly = isComputed value;
            }
            // optionalAttrs (isComputed value) {
              default = tfRef [
                ty
                resource
                config._module.args.name
                attr
              ];
            }
          )
        ) schema.block.attributes;
        config = { };
      }
    );

  providerToOptions =
    schemaType:
    let
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
        modules = map (rm: {
          options = mapAttrs (
            resource: s:
            mkOption {
              type = lazyAttrsOf (blockToType schemaType resource s);
              description = transformDoc s.block;
              default = { };
            }
          ) rm;
        }) ress;
      };
      default = { };
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

in
{
  config = {
    tf =
      { config, ... }:
      {
        options.data = providerToOptions "data";
        options.resource = providerToOptions "resource";
        config = {
        };
      };
  };
  _file = ./tf.nix;
}
