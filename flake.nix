{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    aicommit = {
      url = "github:nguyenvanduocit/ai-commit";
      flake = false;
    };
  };

  outputs = { nixpkgs, aicommit, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      knip = import ./knip { inherit pkgs buildNodeModules; };

      aicommitPkgs = pkgs.buildGoModule {
        name = "ai-commit";
        src = aicommit;
        vendorHash = "sha256-BPxPonschTe8sWc5pATAJuxpn7dgRBeVZQMHUJKpmTk=";
      };

      checkpoint = pkgs.writeShellApplication {
        name = "checkpoint";
        runtimeInputs = [ aicommitPkgs ];
        text = builtins.readFile ./checkpoint.sh;
      };

      buildNodeModules = {
        fromLockJson = packageJson: lockJson:
          let
            locks = pkgs.runCommandNoCC "locks" { } ''
              mkdir -p $out
              cp -L ${packageJson} $out/package.json
              cp -L ${lockJson} $out/package-lock.json
            '';
          in
          pkgs.buildNpmPackage {
            name = "node_modules";
            src = locks;
            npmDeps = pkgs.importNpmLock { npmRoot = locks; };
            npmConfigHook = pkgs.importNpmLock.npmConfigHook;
            dontNpmBuild = true;
            installPhase = "mkdir $out && cp -r node_modules/* $out";
          };

        fromBunLockb = packageJson: lockb:
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
            rm -rf $out/${packageName}
          '';
      };

      packages = { inherit knip checkpoint; };

    in

    {

      devShells.x86_64-linux.default = pkgs.mkShellNoCC {
        buildInputs = [
          checkpoint
        ];
      };

      packages.x86_64-linux = packages;

      checks.x86_64-linux = packages;

      lib = {

        inherit buildNodeModules;

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


      };

    };
}
