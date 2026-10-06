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
          ./assets
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
          # One Flutter build, two apps: the same binary started with --osk is
          # the on-screen keyboard (transparent ARGB window, WM_CLASS
          # hinteros-osk). The wrapper gives it its own name, so the daemon and
          # systemd units start `hinteros-osk` like any other program.
          postInstall = ''
            cat > $out/bin/hinteros-osk <<EOF
            #!${final.runtimeShell}
            exec $out/bin/hinteros-launcher --osk "\$@"
            EOF
            chmod +x $out/bin/hinteros-osk
          '';
          meta = {
            description = "HinterOS launcher UI (and, as hinteros-osk, the on-screen keyboard)";
            license = final.lib.licenses.gpl3Only;
            mainProgram = "hinteros-launcher";
            platforms = [ "x86_64-linux" ];
          };
        };

        # Just bin/hinteros-osk, for systems that want the keyboard on its own
        # (it is the launcher package underneath: one copy of the app).
        hinteros-osk =
          final.runCommand "hinteros-osk"
            {
              meta = {
                description = "HinterOS on-screen keyboard";
                license = final.lib.licenses.gpl3Only;
                mainProgram = "hinteros-osk";
                platforms = [ "x86_64-linux" ];
              };
            }
            ''
              mkdir -p $out/bin
              ln -s ${final.hinteros-launcher}/bin/hinteros-osk $out/bin/hinteros-osk
            '';
      };

      packages.${system} = {
        inherit (pkgs) hinteros-launcher hinteros-osk;
        default = pkgs.hinteros-launcher;

        # Golden PNGs rendered inside the Nix sandbox, the same environment as
        # the `test` check (which compares against the committed ones).
        # `nix run .#update-goldens` copies them into test/golden/goldens.
        goldens = pkgs.hinteros-launcher.overrideAttrs (old: {
          pname = "hinteros-launcher-goldens";
          doCheck = true;
          checkPhase = ''
            runHook preCheck
            export HOME=$TMPDIR
            flutter test --no-pub --update-goldens test/golden
            mkdir -p $TMPDIR/goldens-out
            cp test/golden/goldens/*.png $TMPDIR/goldens-out/
            runHook postCheck
          '';
          postInstall = ''
            mkdir -p $out/goldens
            cp $TMPDIR/goldens-out/*.png $out/goldens/
          '';
        });
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
        inherit (pkgs) hinteros-launcher hinteros-osk;
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
            export HINTEROS_STEAM_FIXTURE=${hinteros-daemon}/crates/hinteros-session/tests/fixtures/steam-home
            export HINTEROS_SYSTEM_BIN=${hinteros-daemon.packages.${system}.hinteros-system}/bin/hinteros-system
            export PATH=${pkgs.openssh}/bin:$PATH
            flutter test --no-pub test/integration
            runHook postCheck
          '';
        });
      };

      # Copies the pinned daemon's schema into schema/ and regenerates the Dart API.
      apps.x86_64-linux.update-schema = {
        type = "app";
        meta.description = "Re-vendor the daemon schema and regenerate the Dart API";
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

      # Regenerates the golden screenshots in the sandbox and copies them here.
      apps.x86_64-linux.update-goldens = {
        type = "app";
        meta.description = "Regenerate the golden test images (in the Nix sandbox, as the check sees them)";
        program = pkgs.lib.getExe (
          pkgs.writeShellApplication {
            name = "update-goldens";
            runtimeInputs = [
              pkgs.nix
              pkgs.coreutils
            ];
            text = ''
              [ -f flake.nix ] || { echo "run from the launcher repo root" >&2; exit 1; }
              out=$(nix build .#goldens --no-link --print-out-paths)
              mkdir -p test/golden/goldens
              rm -f test/golden/goldens/*.png
              install -m 644 "$out"/goldens/*.png test/golden/goldens/
              echo "Updated test/golden/goldens; review the images and commit them."
            '';
          }
        );
      };

      formatter.${system} = pkgs.nixfmt;
    };
}
