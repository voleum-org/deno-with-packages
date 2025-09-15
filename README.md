# Deno with packages

This flake [part](flake.parts) provides utilities for managing Deno dependencies with Nix.

Features:

- reading multiple lock files
- creating a derivation per Deno dependency
- combining those into a single derivation
- wrapping `deno` executable to have it install the cache
- keeping cache in `<flake root>/.deno_cache`

Currently only NPM dependencies are recognized.

## Usage

See `example/flake.nix`
