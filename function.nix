lib: functions: let
  inherit (lib.attrsets) mapAttrs;
  inherit (lib.trivial) throwIfNot;
  inherit (lib) isList isAttrs filter concatStringsSep take optional;
  inherit (builtins) length addErrorContext elemAt;
  inherit (import ./type.nix {inherit lib;}) typeToNix paramTypeToNix;

  renderValue = valueToRender': let
  # functor prevents toPretty from using __pretty, should it be fixed in nixpkgs?
  valueToRender = if isAttrs valueToRender' then removeAttrs valueToRender' ["__functor"] else valueToRender';
  prettyEval = builtins.tryEval (
    lib.generators.toPretty {
      allowPrettyValues = true;
    } (
      lib.generators.withRecursion {
        depthLimit = 10;
        throwOnDepthLimit = false;
      } valueToRender
    )
  );
  # Split it into its lines
  lines = filter (v: !isList v) (builtins.split "\n" prettyEval.value);
  # Only display the first 5 lines, and indent them for better visibility
  value = concatStringsSep "\n    " (take 5 lines ++ optional (length lines > 5) "...");
  result =
    # Don't print any value if evaluating the value strictly fails
    if !prettyEval.success then
      ""
    # Put it on a new line if it consists of multiple
    else if length lines > 1 then
      ":\n    " + value
    else
      ": " + value;
      in result;

  ensureType = type: value: throwIfNot (!(type.check value)) "invalid type, wanted ${type.description}${renderValue value}" value;

  validateParam = param: value: let
  	nixType = paramTypeToNix param;
  in
 		ensureType nixType value;

  processArg = fun: param: value: addErrorContext "while handling argument ${fun}.${param.name}:" (validateParam param value);

  mkCallRef = name: return_type: variadic_parameter: args: {
    _type = "tfCallStrict";
    inherit args;
    variadic = [];
    inherit return_type;

    # val is required for __pretty
    val = {};
    __pretty = v: "«terraform.${name} -> ${(typeToNix return_type).description}»";

    __functor = self: vararg:
      throwIfNot (variadic_parameter != null) "function ${name} has no variadic parameter" (self
        // {
          variadic =
            self.variadic
            ++ [
              (processArg name variadic_parameter vararg)
            ];
        });
  };

  mkRef = path: value_type: {
    _type = "tfRef";
    inherit path;
    index = [];
    inherit value_type;

    __pretty = v: "«terraform.${path} -> ${(typeToNix value_type).description}»";
    __functor = self: index:
   		if self.value_type == "dynamic" then (self // {
       index = self.index ++ [(ensureType indexType index)];
     	})
     	else if isList self.value_type && length self.value_type == 2 && elemAt self.value_type 0 == "list" then (self // {
        value_type = elemAt self.value_type 1;
        index = self.index ++ [(ensureType arrayIndexType index)];
      })
     	else if isList self.value_type && length self.value_type == 2 && elemAt self.value_type 0 == "map" then (self // {
        value_type = elemAt self.value_type 1;
        index = self.index ++ [(ensureType mapIndexType index)];
      })
      else throw "${(typeToNix self.value_type).description} is not indexable by${renderValue index}";
  };

  handleArgs = name: def: let
    aux = collected: i:
      if length (def.parameters or []) == i
      then (mkCallRef name def.return_type (def.variadic_parameter or null) collected)
      else
        arg:
          aux (collected
            ++ [
              (processArg name (elemAt def.parameters i) arg)
            ]) (i + 1);
  in
    aux [] 0;
in
  throwIfNot (functions.format_version == "1.0") "unsupported functions metadata version"
  (mapAttrs handleArgs functions.function_signatures)
