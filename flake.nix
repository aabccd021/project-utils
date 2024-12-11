{
  description = "A very basic flake";

  outputs = { ... }: {

    lib = {

      safeMergeAttrs = builtins.foldl'
        (a: b:
          let
            intersections = builtins.concatStringsSep " " (builtins.attrNames (builtins.intersectAttrs a b));
          in
          if intersections != "" then
            builtins.abort "Duplicate keys detected: ${intersections}"
          else
            a // b
        )
        { };

      biomeFormatExtensions = [
        "*.js"
        "*.ts"
        "*.mjs"
        "*.mts"
        "*.cjs"
        "*.cts"
        "*.jsx"
        "*.tsx"
        "*.d.ts"
        "*.d.cts"
        "*.d.mts"
        "*.json"
        "*.jsonc"
        "*.css"
      ];

      imageExtensions = [
        "*.txt"
        "*.png"
        "*.jpg"
        "*.webp"
      ];


      buildNodeModules = {
        fromLockJson = pkgs: packageJson: lockJson:
          let
            locks = pkgs.runCommandNoCC "locks" { } ''
              mkdir -p $out
              cp -L ${packageJson} $out/package.json
              cp -L ${lockJson} $out/package-lock.json
            '';
          in
          pkgs.buildNpmPackage
            {
              name = "node_modules";
              src = locks;
              npmDeps = pkgs.importNpmLock { npmRoot = locks; };
              npmConfigHook = pkgs.importNpmLock.npmConfigHook;
              dontNpmBuild = true;
              installPhase = "mkdir $out && cp -r node_modules/* $out";
            };


        fromBunLockb = pkgs: packageJson: lockb:
          let
            yarnSrc = pkgs.runCommand "yarn-src" { } ''
              mkdir -p $out
              ${pkgs.bun}/bin/bun ${lockb} > $out/yarn.lock
              ln -s ${packageJson} $out/package.json
            '';
            raw = pkgs.mkYarnPackage { src = yarnSrc; name = "node_modules"; };
            packageName = (builtins.fromJSON (builtins.readFile packageJson)).name;
          in
          pkgs.runCommand "node_modules" { } ''
            mkdir -p $out
            ln -s ${raw}/libexec/${packageName}/node_modules/* $out
          '';
      };

    };

  };
}
