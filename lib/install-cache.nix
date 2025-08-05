{ pkgs, cache }:

pkgs.writeShellScriptBin "install-deno-cache" ''
  set -euo pipefail

  if [ -z "''${DENO_DIR:-}" ]; then
    echo "Error: DENO_DIR environment variable must be set" >&2
    exit 1
  fi

  echo "Installing Deno cache to: $DENO_DIR"

  # Remove existing cache if it exists
  if [ -d "$DENO_DIR" ]; then
    echo "Removing existing cache..."
    rm -rf "$DENO_DIR"
  fi

  # Copy the shared cache, dereferencing symlinks
  if [ -d "${cache}" ]; then
    echo "Copying shared cache..."
    mkdir -p "$(dirname "$DENO_DIR")"
    cp -rL "${cache}" "$DENO_DIR"
    chmod -R u+w "$DENO_DIR"
    echo "Cache installed successfully!"
  else
    echo "No shared cache found at ${cache}"
    mkdir -p "$DENO_DIR"
  fi

  if [ -d "$DENO_DIR/npm" ]; then
    echo "NPM packages in cache: $(find "$DENO_DIR/npm" -name "package.json" | wc -l)"
  fi
''
