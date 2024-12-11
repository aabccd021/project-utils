{ pkgs, buildNodeModules }:
let
  nodeModules = buildNodeModules.fromLockJson pkgs ./package.json ./package-lock.json;

in
pkgs.writeShellScriptBin "knip" ''
  ${pkgs.bun}/bin/bun run ${nodeModules}/knip/bin/knip.js
''

