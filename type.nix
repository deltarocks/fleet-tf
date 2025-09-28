{lib}:
let
inherit (lib) isList length elemAt isType;
inherit(lib.types) str bool mkOptionType listOf attrsOf nullOr number either;
nullT = mkOptionType {
	name = "null";
	description = "null";
	descriptionClass = "noun";
	check = v: v == null;
};
dynamic = mkOptionType {
	name = "dynamic";
	description = "dynamic";
	descriptionClass = "noun";
	check = v: v != null;
};
tfCompatibleWith = o: t: t // {
  check = v: t.check v || (isCallType v) && (compatibleTypes o v.return_type);
};
isCallType = isType "tfCallStrict";

paramTypeToNix = param: if param ? is_nullable then nullOr (typeToNix param.type) else typeToNix param.type;

arrayIndexType = typeToNix "number";
mapIndexType = typeToNix "string";
indexType = either mapIndexType arrayIndexType;

typeToNix = t: tfCompatibleWith t (typeToNix' t);

typeToNix' = t:
	if isList t && length t == 2 then (
		if elemAt t 0 == "list" then listOf (typeToNix' (elemAt t 1))
		else if elemAt t 0 == "set" then listOf (typeToNix' (elemAt t 1))
		else if elemAt t 0 == "map" then attrsOf (typeToNix' (elemAt t 1))
		else throw "unknown composite type"
	)
	else if isList t then throw "unknown composite type"
	else if t == "string" then str
	else if t == "number" then number
	else if t == "bool" then bool
	else if t == "dynamic" then dynamic
	else if t == "null" then nullT
	else throw "unknown type";

compatibleTypes = a: b:  a == b || a == "dynamic" || b == "dynamic" || isList a && isList b && length a == 2 && length b == 2 && elemAt a 0 == elemAt b 0 && compatibleTypes (elemAt a 1) (elemAt b 1);
in {
  inherit typeToNix paramTypeToNix indexType mapIndexType arrayIndexType;
}
