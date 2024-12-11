{ pkgs, buildNodeModules }:
let
  nodeModules = buildNodeModules.fromLockJson ./package.json ./package-lock.json;

in
# pkgs.writeShellScriptBin "knip" ''
#   ${pkgs.bun}/bin/bun run ${nodeModules}/knip/bin/knip.js "$@"
# ''

pkgs.runCommandLocal "knip" { } ''
  mkdir -p "$out/bin"
  cp -Lr ${nodeModules} $out/node_modules
  echo "${pkgs.bun}/bin/bun run $out/node_modules/knip/bin/knip.js" > $out/bin/knip
  chmod +x $out/bin/knip
''

