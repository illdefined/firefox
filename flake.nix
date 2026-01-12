{
  description = "Custom Firefox build";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
  };

  nixConfig = {
    extra-experimental-features = [ "pipe-operator" ];
    extra-substituters = [ "https://cache.kyouma.net" ];
    extra-trusted-public-keys = [ "cache.kyouma.net:Frjwu4q1rnwE/MnSTmX9yx86GNA/z3p/oElGvucLiZg=" ];
  };

  outputs = { self, nixpkgs, ... }: let
    inherit (nixpkgs) lib;
    eachSystem = fn: lib.genAttrs [
      "aarch64-linux"
      "riscv64-linux"
      "x86_64-linux"
      "aarch64-darwin"
    ] (system: fn system (import nixpkgs {
      inherit system;
      overlays = [ self.overlays.default ];
    }));
  in {
    overlays.default = final: prev: let
      wrapper = prevAttrs: {
        buildCommand = prevAttrs.buildCommand + ''
          sed -i \
            -e '$i export LD_PRELOAD="${lib.getLib final.mimalloc}/lib/libmimalloc-secure.so"' \
            "$out/bin/${prevAttrs.meta.mainProgram}"
        '';
      };

      unwrapped = prevAttrs: {
        configureFlags = prevAttrs.configureFlags or [ ] ++ [
          "--disable-accessibility"
        ] ++ lib.optionals final.stdenv.hostPlatform.isLinux [
          "--enable-default-toolkit=cairo-gtk3-wayland-only"
        ];

        postPatch = prevAttrs.postPatch or "" + ''
          find . -type f -name moz.configure -print0 \
            | xargs -0 -r sed -E -i \
              's/^([a-z_]+\("MOZ_(DATA_REPORTING|SERVICES_HEALTHREPORT|NORMANDY|TELEMETRY_REPORTING)",[[:space:]]*)True\>/\1False/'
        '';

        meta = prevAttrs.meta or { } // {
          timeout = 24 * 3600;
          maxSilent = 8 * 3600;
        };
      };

      xvfb-run = if prev.stdenv.hostPlatform.isLinux
        then final.writeShellApplication {
          name = "xvfb-run";
          text = ''
            # Discard all options
            while [[ "$1" =~ ^- ]]; do
              case "$1" in
                (-e|-f|-n|-p|-s|-w) shift ;&
                (*) shift ;;
              esac
            done

            WLR_BACKENDS=headless \
            WLR_LIBINPUT_NO_DEVICES=1 \
            WLR_RENDERER=pixman \
            XDG_RUNTIME_DIR="$(mktemp -d)" \
              exec '${lib.getExe final.cage}' -- "$@"
          '';

          # shellcheck is not yet available on RISC-V
          checkPhase = if final.stdenv.buildPlatform.isRiscV then ''
            runHook preCheck
            ${final.stdenv.shellDryRun} "$target"
            runHook postCheck
          '' else null;
        }
        else prev.xvfb-run;
    in {
      firefox = (final.wrapFirefox final.firefox-unwrapped {
        cfg = {
          smartcardSupport = true;
        } // final.config.firefox or { };

        extraPolicies = import ./policy.nix { inherit lib; firefox = true; };
      }).overrideAttrs wrapper;

      firefox-unwrapped = (prev.firefox-unwrapped.overrideAttrs unwrapped).override {
        gssSupport = false;
        jackSupport = false;
        jemallocSupport = false;
        sndioSupport = false;

        inherit xvfb-run;
      };

      mimalloc = (prev.mimalloc.overrideAttrs (prevAttrs: {
        postPatch = prevAttrs.postPatch or "" + ''
        sed -E -i \
          -e 's/(\{ )1(, UNINIT, MI_OPTION_LEGACY\(purge_decommits,reset_decommits\) \})/\10\2/' \
          -e 's/(\{ )10(,  UNINIT, MI_OPTION_LEGACY\(purge_delay,reset_delay\) \})/\150\2/' \
          src/options.c
        '';
      })).override {
        secureBuild = true;
      };

      opensc = prev.opensc.overrideAttrs (prevAttrs: {
        version = "0.26.1-unstable-2026-01-09";

        src = final.fetchFromGitHub {
          inherit (prevAttrs.src) owner repo;
          rev = "006a2192a26ebe9df73a5b259a0dcca3a4db1c4d";
          hash = "sha256-SjDrUQe+d326Izq+5JzT2QGuw+c3RUVN2TLGmrRrNKk=";
        };
      });

      thunderbird = (final.wrapThunderbird final.thunderbird-unwrapped {
        cfg = {
          smartcardSupport = true;
        } // final.config.thunderbird or { };

        extraPoliciesFiles =
          import ./policy.nix { inherit lib; thunderbird = true; }
          |> final.writers.writeJSON "policy.json"
          |> lib.singleton;
      }).overrideAttrs wrapper;

      thunderbird-unwrapped = (prev.thunderbird-latest-unwrapped.overrideAttrs unwrapped).override {
        jackSupport = false;
        jemallocSupport = false;
        sndioSupport = false;

        privacySupport = true;
        #drmSupport = false;

        inherit xvfb-run;
      };
    };

    packages = eachSystem (system: pkgs: {
      default = self.packages.${system}.firefox;

      inherit (pkgs)
        firefox
        firefox-unwrapped
        thunderbird
        thunderbird-unwrapped;
    });

    hydraJobs = self.packages |> lib.foldlAttrs (jobs: system: packages: lib.recursiveUpdate jobs
      (lib.mapAttrs (name: package: { ${system} = lib.hydraJob package; }) packages)) { };
  };
}
