# Deno with packages

This flake provides utilities for managing Deno dependencies with Nix,
- reading multiple lock files
- creating a derivation per Deno dependency
- combining those into a single derivation
- installing shared cache into `DENO_DIR`

Currently only NPM dependencies are recognized.

## Usage

See `flake.nix`
