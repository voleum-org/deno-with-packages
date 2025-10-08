{
  description = "Provides a Deno executable wrapper pointing to pre-built NPM dependency cache based on lock files";

  outputs = { ... }: {
    flakeModule = ./flake-module.nix;
  };
}
