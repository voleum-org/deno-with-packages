{
  description = "Usage example";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-root.url = "github:srid/flake-root";
    # replace with "github:voleum-org/deno-with-packages"
    deno-with-packages.url = "path:../";
  };

  outputs = inputs@{ flake-parts, flake-root, deno-with-packages, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        flake-root.flakeModule
        deno-with-packages.flakeModule
      ];

      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      perSystem = { config, pkgs, ... }: {
        deno = {
          enable = true;
          lockfiles = [ ./deno.lock ];
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [ config.flake-root.devShell ];
          buildInputs = [ config.packages.deno ];
        };
      };
    };
}
