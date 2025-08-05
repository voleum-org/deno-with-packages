{
  description = "Builds a shared cache for Deno packages based on lock files";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in rec
      {
        lib = {
          # Extract NPM dependencies from a single Deno lock file
          denoLockfileToNpmDeps = import ./lib/lockfile-to-npm-deps.nix { self = lib; };

          # Create a shared Deno cache from multiple lock files
          denoSharedCache = import ./lib/shared-cache.nix { self = lib; };

          # Install shared cache into DENO_DIR
          installDenoCache = import ./lib/install-cache.nix;

          denoNpmRegistryHostname = "registry.npmjs.org";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            deno
          ];

          shellHook = 
            let
              # Example
              sharedCache = self.lib.${system}.denoSharedCache {
                inherit pkgs;
                lockfiles = [ ./deno.lock ]; # Add your lock files here
              };
              installScript = self.lib.${system}.installDenoCache {
                inherit pkgs;
                cache = sharedCache;
              };
            in
            ''
              export DENO_DIR="$PWD/.deno_cache"

              if [ -d "${sharedCache}" ]; then
                echo "Installing Deno shared cache..."
                ${installScript}/bin/install-deno-cache
              fi

              echo "Deno development environment ready!"
              echo "DENO_DIR is set to: $DENO_DIR"
            '';
        };
      }
    );
}
