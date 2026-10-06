{
  description = "HinterOS launcher: the Flutter home UI for the gamescope session";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      git-hooks,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      };

      # Sources that matter to the build; keeps build/ and .dart_tool/ out.
      src = pkgs.lib.fileset.toSource {
        root = ./.;
        fileset = pkgs.lib.fileset.unions [
          ./pubspec.yaml
          ./pubspec.lock
          ./analysis_options.yaml
          ./lib
          ./linux
          ./test
        ];
      };

      dartHooks = {
        dart-format = {
          enable = true;
          name = "dart format";
          entry = "${pkgs.flutter}/bin/dart format --set-exit-if-changed";
          files = "\\.dart$";
        };
      };

      # `dart analyze` needs the pub packages, which the sandboxed hook run does
      # not have; it runs in checks.test instead and is a real hook in the shell.
      hooksFor =
        withAnalyze:
        git-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            nixfmt.enable = true;
          }
          // dartHooks
          // pkgs.lib.optionalAttrs withAnalyze {
            dart-analyze = {
              enable = true;
              name = "dart analyze";
              entry = "${pkgs.flutter}/bin/flutter analyze";
              files = "\\.dart$";
              pass_filenames = false;
            };
          };
        };
    in
    {
      overlays.default = final: _prev: {
        hinteros-launcher = final.flutter.buildFlutterApplication {
          pname = "hinteros-launcher";
          version = "0.1.0";
          inherit src;
          autoPubspecLock = src + "/pubspec.lock";
          meta = {
            description = "HinterOS launcher UI";
            license = final.lib.licenses.gpl3Only;
            mainProgram = "hinteros-launcher";
            platforms = [ "x86_64-linux" ];
          };
        };
      };

      packages.${system} = {
        inherit (pkgs) hinteros-launcher;
        default = pkgs.hinteros-launcher;
      };

      devShells.${system}.default = pkgs.mkShell {
        inputsFrom = [ pkgs.hinteros-launcher ];
        packages = [
          pkgs.flutter
          pkgs.cmake
          pkgs.ninja
          pkgs.clang
          pkgs.mesa-demos
          pkgs.gamescope
          pkgs.nixfmt
        ];
        shellHook = (hooksFor true).shellHook;
      };

      checks.${system} = {
        inherit (pkgs) hinteros-launcher;
        pre-commit = hooksFor false;

        # dart analyze + flutter test inside the sandbox (flutter_tester is headless).
        test = pkgs.hinteros-launcher.overrideAttrs (old: {
          pname = "hinteros-launcher-test";
          doCheck = true;
          checkPhase = ''
            runHook preCheck
            export HOME=$TMPDIR
            flutter analyze --no-pub
            flutter test --no-pub
            runHook postCheck
          '';
        });
      };

      formatter.${system} = pkgs.nixfmt;
    };
}
