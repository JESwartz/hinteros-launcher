{
  description = "HinterOS launcher: the Flutter home UI for the gamescope session";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # The API schema (and the real session daemon for the integration check).
    hinteros-daemon = {
      url = "git+https://justsomeshed.com/JSwartz/HinterOS/hinteros-daemon.git";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.git-hooks.follows = "git-hooks";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      git-hooks,
      hinteros-daemon,
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
          ./schema
          ./tool
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

        # The vendored schema must equal the one the pinned daemon ships.
        schema-vendored =
          pkgs.runCommand "hinteros-launcher-schema-vendored"
            {
              vendored = ./schema/session-api.json;
              upstream = "${hinteros-daemon}/schema/session-api.json";
            }
            ''
              if ! diff -u "$upstream" "$vendored"; then
                echo
                echo "schema/session-api.json differs from hinteros-daemon's schema/session-api.json."
                echo "Re-vendor it and regenerate the Dart API:"
                echo "    nix flake update hinteros-daemon   # if you want the daemon's latest"
                echo "    nix run .#update-schema"
                echo "then commit schema/ and lib/src/api/generated.dart."
                exit 1
              fi
              touch "$out"
            '';

        # lib/src/api/generated.dart must be what the generator emits for the vendored schema.
        generated =
          pkgs.runCommand "hinteros-launcher-generated"
            {
              nativeBuildInputs = [ pkgs.flutter ];
            }
            ''
              export HOME=$TMPDIR
              cd ${src}
              dart tool/gen_api.dart --check
              touch "$out"
            '';

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

        # The real hinteros-session on a temp socket, driven by the Dart client.
        integration = pkgs.hinteros-launcher.overrideAttrs (old: {
          pname = "hinteros-launcher-integration";
          doCheck = true;
          checkPhase = ''
            runHook preCheck
            export HOME=$TMPDIR
            export HINTEROS_SESSION_BIN=${
              hinteros-daemon.packages.${system}.hinteros-session
            }/bin/hinteros-session
            flutter test --no-pub test/integration
            runHook postCheck
          '';
        });
      };

      # Copies the pinned daemon's schema into schema/ and regenerates the Dart API.
      apps.${system}.update-schema = {
        type = "app";
        program = pkgs.lib.getExe (
          pkgs.writeShellApplication {
            name = "update-schema";
            runtimeInputs = [
              pkgs.flutter
              pkgs.coreutils
            ];
            text = ''
              [ -f flake.nix ] || { echo "run from the launcher repo root" >&2; exit 1; }
              install -m 644 ${hinteros-daemon}/schema/session-api.json schema/session-api.json
              dart tool/gen_api.dart
              echo "Re-vendored schema/session-api.json and regenerated lib/src/api/generated.dart; commit both."
            '';
          }
        );
      };

      formatter.${system} = pkgs.nixfmt;
    };
}
