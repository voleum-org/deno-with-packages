{ self }:
{ pkgs, lockfile }:
let
  registry = self.denoNpmRegistryHostname;

  # Extract npm dependencies from a single lockfile
  extractNpmDeps = lockfile:
    let
      lockJSON = builtins.fromJSON (builtins.readFile lockfile);
    in
      lockJSON.npm or {};

  npmDeps = extractNpmDeps lockfile;

  # Create tarball derivation for a package
  mkTarballDrv = { name, version, integrity }:
    let
      tarballName =
        if builtins.substring 0 1 name == "@" 
        then builtins.baseNameOf name  # "@types/node" → "node"
        else name;
    in
      pkgs.fetchurl {
        url = "https://${registry}/${name}/-/${tarballName}-${version}.tgz";
        hash = integrity;
      };

  # Create derivation for a single npm package
  mkNpmDep = key: value:
    let
      match = builtins.match "(@?[^@]+)@([^_]+).*" key;
      name = builtins.elemAt match 0;
      version = builtins.elemAt match 1;
    in
    pkgs.stdenv.mkDerivation {
      pname = "deno-npm-${builtins.replaceStrings ["@" "/"] ["" "-"] name}";
      version = version;
      src = mkTarballDrv {
        inherit name version; 
        inherit (value) integrity;
      };

      installPhase = ''
        runHook preInstall

        export OUT_PATH="$out/npm/${registry}/${name}/${version}"

        mkdir -p $OUT_PATH
        tar -xzf $src -C $OUT_PATH --strip-components=1

        cat > $OUT_PATH/../registry.json <<EOF
{
  "name": "${name}",
  "dist-tags": {},
  "versions": {
    "${version}": {
      "version": "${version}"
    }
  }
}
EOF

        runHook postInstall
      '';
    };

in
pkgs.lib.mapAttrsToList mkNpmDep npmDeps
