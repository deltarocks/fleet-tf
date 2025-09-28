{lib, runCommand, terraform-locked, writeText}:
let
	inherit (lib) imap1 nameValuePair listToAttrs;
	fake_tf_json = writeText "fake.tf.json" (builtins.toJSON {
		terraform.required_providers = listToAttrs(imap1 (i: provider: nameValuePair "prov${toString i}" {
			source = provider.provider-source-address;
		}) terraform-locked.providers);
	});
in
runCommand "providers.json" {} ''
  cp ${fake_tf_json} fake.tf.json
  ${lib.getExe terraform-locked} init
	${lib.getExe terraform-locked} providers schema -json > $out
''
