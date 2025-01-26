lib: functions: let
  inherit (lib.attrsets) mapAttrs;
  inherit (lib.trivial) throwIfNot;
  inherit (builtins) length deepSeq addErrorContext elemAt;

  processArg = fun: name: value: addErrorContext "while handling argument ${fun}.${name}:" (deepSeq value value);

  handleVarArgs = name: def: args: {
    _type = "tfCallStrict";
    inherit args;
    variadic = [];
    __functor = self: vararg:
      throwIfNot (def ? variadic_parameter) "function ${name} has no variadic parameter" (self
        // {
          variadic =
            self.variadic
            ++ [
              (processArg name "<variadic>" vararg)
            ];
        });
  };

  handleArgs = name: def: let
    aux = collected: i:
      if length (def.parameters or []) == i
      then (handleVarArgs name def collected)
      else
        arg:
          aux (collected
            ++ [
              (processArg name ((elemAt def.parameters i).name) arg)
            ]) (i + 1);
  in
    aux [] 0;
in
  throwIfNot (functions.format_version == "1.0") "unsupported functions metadata version"
  (mapAttrs handleArgs functions.function_signatures)
