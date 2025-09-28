{
  runCommand,
  makeWrapper,
  terraform,
  terraform-lockfile,
  providers ? p: [],
}: let
  terraform-patched = terraform.overrideAttrs (oldAttrs: {
    patches =
      (oldAttrs.patches or [])
      ++ [
        ./0001-feat-override-lockfile-path.patch
      ];
  });
  realProviders = providers terraform-patched.plugins;
  terraform-wrapped = terraform-patched.withPlugins (p: realProviders);
  lockfile = terraform-lockfile.override {
    providersDirectory = toString terraform-wrapped;
    providers = realProviders;
  };
in
  runCommand "terraform-with-plugins" {
    nativeBuildInputs = [makeWrapper];
    passthru.providers = realProviders;

    meta.mainProgram = "terraform";
  } ''
    mkdir -p $out/bin/
    makeWrapper "${terraform-wrapped}/bin/terraform" "$out/bin/terraform" \
      --set NIX_TERRAFORM_LOCKFILE ${lockfile}
  ''
