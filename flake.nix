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
      # M7: the m7 branch. Revert to main (drop ?ref=m7) when M7 merges.
      url = "git+https://justsomeshed.com/JSwartz/HinterOS/hinteros-daemon.git?ref=m7";
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

        # The pure logic that recognises GTK's GLX dummy window (never a
        # foreign client's window, never GDK's own).
        gl-dummy-logic = pkgs.runCommandCC "hinteros-launcher-gl-dummy-logic" { } ''
          g++ -Wall -Werror -I${./linux/runner} ${./linux/runner/gl_dummy_test.cc} -o test
          ./test
          touch "$out"
        '';

        # The real launcher (console mode, then the keyboard) under a bare X
        # server: after startup no override-redirect viewable window of its
        # client may remain (GTK's GL dummy would black out gamescope), and its
        # toplevel must be viewable.
        x11-gl-dummy =
          pkgs.runCommand "hinteros-launcher-x11-gl-dummy"
            {
              nativeBuildInputs = [
                pkgs.xorg-server
                pkgs.xwininfo
              ];
            }
            ''
              export HOME=$TMPDIR XDG_RUNTIME_DIR=$TMPDIR
              export LIBGL_ALWAYS_SOFTWARE=1 GDK_BACKEND=x11 NO_AT_BRIDGE=1
              export LIBGL_DRIVERS_PATH=${pkgs.mesa}/lib/dri
              export LD_LIBRARY_PATH=${pkgs.libGL}/lib:${pkgs.mesa}/lib
              export __EGL_VENDOR_LIBRARY_FILENAMES=${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json
              Xvfb :77 -screen 0 1920x1080x24 -nolisten tcp -nolisten unix \
                -xkbdir ${pkgs.xkeyboard_config}/etc/X11/xkb &
              xpid=$!
              trap 'kill $xpid ''${app:-} 2>/dev/null || true' EXIT
              export DISPLAY=:77
              for _ in $(seq 50); do xwininfo -root >/dev/null 2>&1 && break; sleep 0.2; done

              check() {
                name=$1; shift
                "$@" >app.log 2>&1 &
                app=$!
                sleep 10
                cat app.log
                xwininfo -root -children | tee tree.txt
                # Windows of the app's client share the resource base of
                # its named toplevel.
                top=""
                for id in $(sed -n 's/^ *\(0x[0-9a-f]*\) "[^"]*".*/\1/p' tree.txt); do
                  if xwininfo -id "$id" -stats | grep -q 'Map State: IsViewable'; then top=$id; break; fi
                done
                if [ -z "$top" ]; then echo "$name: no viewable toplevel"; exit 1; fi
                base=$(( top & ~0x1fffff ))
                if ! xwininfo -id "$top" -stats | grep -q 'Map State: IsViewable'; then
                  echo "$name: toplevel $top not viewable"; exit 1
                fi
                for id in $(sed -n 's/^ *\(0x[0-9a-f]*\) .*/\1/p' tree.txt); do
                  [ $(( id & ~0x1fffff )) -eq $base ] || continue
                  stats=$(xwininfo -id "$id" -stats)
                  if echo "$stats" | grep -q 'Override Redirect State: yes' &&
                     echo "$stats" | grep -q 'Map State: IsViewable'; then
                    echo "$name: override-redirect viewable window $id remains"; exit 1
                  fi
                done
                grep -q 'unmapped GDK GL dummy window' app.log ||
                  echo "$name: note: no GL dummy was found"
                kill $app; wait $app 2>/dev/null || true
              }

              check launcher ${pkgs.hinteros-launcher}/bin/hinteros-launcher
              check osk ${pkgs.hinteros-launcher}/bin/hinteros-osk
              touch "$out"
            '';

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
