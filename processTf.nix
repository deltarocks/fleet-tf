lib: let
  inherit (lib.attrsets) filterAttrs optionalAttrs mapAttrs;
  inherit (lib.trivial) isString;
  inherit (lib.strings) concatStringsSep concatMapStringsSep;
  inherit (lib.lists) join;

  notRefTo = v: to: !(v ? _type) || v._type != "tfRef" || v.ref != to;

  strAttrInner = v:
    if v._type == "tfRef"
    then concatStringsSep "." v.ref
    else if v._type == "tfCall"
    # TODO: Some params might not be strings?..
    then "${v.fn}(${concatMapStringsSep ", " strAttrInner v.params})"
    else throw "idk: ${v._type}";
  strAttr = attr:
    if attr ? _type
    then "\${${strAttrInner attr}}"
    else attr;

  processResource = sectName: groupName: resName: resource:
    mapAttrs (param: val: strAttr val)
    (filterAttrs (
        attrName: v:
          notRefTo v [sectName groupName resName attrName]
      )
      resource);

  processGroup = sectName: groupName: group: mapAttrs (processResource sectName groupName) group;

  processSection = sectName: section:
    mapAttrs (processGroup sectName) (filterAttrs (_: v: v != {}) section);
  processTf = conf: let
    data = processSection "data" conf.data;
    resource = processSection "resource" conf.resource;
  in
    optionalAttrs (data != {}) {inherit data;} // optionalAttrs (resource != {}) {inherit resource;};
in
  processTf
