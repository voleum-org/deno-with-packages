{ self }:
{ pkgs, lockfiles }:
let
  allNpmDeps = builtins.concatMap
    (lockfile:
      self.denoLockfileToNpmDeps { inherit pkgs lockfile; })
    lockfiles;

in
pkgs.symlinkJoin {
  name = "deno-shared-cache";
  paths = allNpmDeps;
}
