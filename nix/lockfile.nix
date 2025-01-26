{
  lib,
  runCommand,
  terraform-calculator,
  providersDirectory ? "/var/lib/empty",
  providers ? [],
}: let
  inherit (lib) concatMapStringsSep;
  hashOfPackage' = attrs:
    runCommand "pkg-hash" {} ''
      ${lib.getExe terraform-calculator} "-provider-path=${providersDirectory}" "-source-address=${attrs.provider-source-address}" "-version=${attrs.version}" > $out
    '';
in
  runCommand ".terraform.lock.hcl" {} (concatMapStringsSep "\n\n" (
      pkg: let
        hash-drv = hashOfPackage' pkg;
      in ''
        echo "# From ${toString pkg}" >> $out
        echo "provider \"${pkg.provider-source-address}\" {" >> $out
        echo "  version = \"${pkg.version}\"" >> $out
        echo "  hashes = [" >> $out
        while IFS= read -r line; do
        echo "    $line" >> $out
        done < ${hash-drv}
        echo "  ]" >> $out
        echo "}" >> $out
      ''
    )
    providers)
