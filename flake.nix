{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    aicommit = {
      url = "github:nguyenvanduocit/ai-commit";
      flake = false;
    };
  };

  outputs = { nixpkgs, aicommit, treefmt-nix, self }:
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

      packages = {
        inherit knip checkpoint;
        formatting = treefmtEval.config.build.check self;
      };

      treefmtEval = treefmt-nix.lib.evalModule pkgs {
        projectRootFile = "flake.nix";
        programs.nixpkgs-fmt.enable = true;
        programs.prettier.enable = true;
        programs.shfmt.enable = true;
        programs.shellcheck.enable = true;
        settings.formatter.shellcheck.options = [ "-s" "sh" ];
      };

    in

    {

      devShells.x86_64-linux.default = pkgs.mkShellNoCC {
        buildInputs = [
          checkpoint
        ];
      };

      packages.x86_64-linux = packages;

      checks.x86_64-linux = packages;

      formatter.x86_64-linux = treefmtEval.config.build.wrapper;

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

      };

    };
}
