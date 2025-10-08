{ self, lib, flake-parts-lib, ... }:
let
  inherit (flake-parts-lib) mkPerSystemOption;
  inherit (lib) mkOption mkEnableOption types;
in
{
  options = {
    flake.lib.deno = mkOption {
      type = types.attrs;
      default = {};
      description = "Deno-related library functions";
    };
  };

  options.perSystem = mkPerSystemOption ({ pkgs, system, ... }: {
    options.deno = {
      enable = mkEnableOption "Deno with shared cache support";
      
      lockfiles = mkOption {
        type = types.listOf types.path;
        default = [];
        description = "List of deno.lock files to build cache from";
      };

      package = mkOption {
        type = types.package;
        default = pkgs.deno;
        description = "Base deno package to wrap";
      };

      registryHostname = mkOption {
        type = types.str;
        default = "registry.npmjs.org";
        description = "NPM registry hostname";
      };
    };
  });

  config = {
    flake.lib.deno = rec {
      denoLockfileToNpmDeps = { pkgs, lockfile, registryHostname }:
        let
          extractNpmDeps = lockfile:
            let
              lockJSON = builtins.fromJSON (builtins.readFile lockfile);
            in
              lockJSON.npm or {};

          npmDeps = extractNpmDeps lockfile;

          mkTarballDrv = { name, version, integrity }:
            let
              tarballName =
                if builtins.substring 0 1 name == "@" 
                then builtins.baseNameOf name  # "@types/node" -> "node"
                else name;
            in
              pkgs.fetchurl {
                url = "https://${registryHostname}/${name}/-/${tarballName}-${version}.tgz";
                hash = integrity;
              };

          mkNpmDep = key: value:
            let
              match = builtins.match "(@?[^@]+)@([^_]+).*" key;
              name = builtins.elemAt match 0;
              version = builtins.elemAt match 1;
              cachePath = "npm/${registryHostname}/${name}";
            in {
              drv = pkgs.stdenv.mkDerivation {
                pname = "deno-npm-${builtins.replaceStrings ["@" "/"] ["" "-"] name}";
                version = version;
                src = mkTarballDrv {
                  inherit name version; 
                  inherit (value) integrity;
                };

                installPhase = ''
                  runHook preInstall
  
                  export OUT_PATH="$out/${cachePath}/${version}"
  
                  mkdir -p $OUT_PATH
                  tar -xzf $src -C $OUT_PATH --strip-components=1

                  runHook postInstall
                '';
              };
              inherit name cachePath;
            };
        in
          pkgs.lib.mapAttrsToList mkNpmDep npmDeps;

      denoSharedCache = { pkgs, lockfiles, registryHostname }:
        let
          allNpmDeps = builtins.concatMap
            (lockfile: denoLockfileToNpmDeps { 
              inherit pkgs lockfile registryHostname; 
            })
            lockfiles;
          sharedCacheBase = pkgs.symlinkJoin {
            name = "deno-shared-cache-base";
            paths = map (d: d.drv) allNpmDeps;
          };
        in
          pkgs.runCommand "deno-shared-cache" {} ''
            runHook preInstall

            mkdir -p $out
            chmod -R +w $out

            cp -rs ${sharedCacheBase}/* $out

            while IFS='|' read -r dep name; do
              chmod +w $out/$dep
cat > $out/$dep/registry.json <<EOF
{
  "name": "$name",
  "dist-tags": {},
  "versions": {}
}
EOF
              while IFS= read -r ver; do
                SUBSET_FILTER='to_entries | map(select(.key == "version" or .key == "bin" or .key == "dependencies" or .key == "peerDependencies")) | from_entries'
                PACKAGE_SUBSET=$(${pkgs.jq}/bin/jq "$SUBSET_FILTER" $out/$dep/$ver/package.json)
                 ${pkgs.jq}/bin/jq --arg version "$ver" --argjson subset "$PACKAGE_SUBSET" \
                   '.versions[$version] = $subset' \
                   $out/$dep/registry.json > $out/$dep/registry.json.tmp

                mv $out/$dep/registry.json.tmp $out/$dep/registry.json
              done < <(find $out/$dep -mindepth 1 -maxdepth 1 -type d | xargs -n1 basename)
            done < <(echo "${builtins.concatStringsSep "\n" (map (d: "${d.cachePath}|${d.name}") allNpmDeps)}" | sort -u)

            runHook postInstall
          '';

      denoWithCache = { pkgs, baseDeno, sharedCache }:
        pkgs.writeShellScriptBin "deno" ''
          set -euo pipefail

          if [ -n "''${FLAKE_ROOT:-}" ]; then
            CACHE_DIR="$FLAKE_ROOT/.deno_cache"
          else
            echo "FLAKE_ROOT not set. Make sure you're using the flake-root devShell." >&2
            exit 1
          fi

          if [ ! -d "$CACHE_DIR" ] || [ ! "$(ls -A "$CACHE_DIR" 2>/dev/null)" ]; then
            echo "Setting up Deno cache at: $CACHE_DIR" >&2
            mkdir -p "$CACHE_DIR"
            
            if [ -d "${sharedCache}" ]; then
              echo "Copying shared cache..." >&2
              cp -rL "${sharedCache}"/* "$CACHE_DIR"/ 2>/dev/null || true
              chmod -R u+w "$CACHE_DIR" 2>/dev/null || true
            fi
          fi
      
          export DENO_DIR="$CACHE_DIR"
          exec "${baseDeno}/bin/deno" "$@"
        '';
    };

    perSystem = { config, pkgs, system, ... }: 
      lib.mkIf config.deno.enable {
        packages = lib.mkIf (config.deno.lockfiles != []) {
          deno = 
            let
              sharedCache = self.lib.deno.denoSharedCache {
                inherit pkgs;
                lockfiles = config.deno.lockfiles;
                registryHostname = config.deno.registryHostname;
              };
            in
              self.lib.deno.denoWithCache {
                inherit pkgs sharedCache;
                baseDeno = config.deno.package;
              };

          deno-cache = self.lib.deno.denoSharedCache {
            inherit pkgs;
            lockfiles = config.deno.lockfiles;
            registryHostname = config.deno.registryHostname;
          };
        };
      };
  };
}
