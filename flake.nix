{
  description = "Builds a shared cache for Deno packages based on lock files";

  outputs = { ... }: {
    flakeModule = ./flake-module.nix;
  };
}
