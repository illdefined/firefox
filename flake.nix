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
        hardeningEnable = prevAttrs.hardeningEnable or [ ] ++ [ "pie" ];

        configureFlags = prevAttrs.configureFlags or [ ] ++ [
          "--disable-accessibility"
        ] ++ lib.optionals final.stdenv.hostPlatform.isLinux [
          "--enable-default-toolkit=cairo-gtk3-wayland-only"
        ];

        postPatch = prevAttrs.postPatch or "" + ''
          find . -type f -name moz.configure -print0 \
            | xargs -0 -r sed -E -i \
              's/^([a-z_]+\("MOZ_(DATA_REPORTING|SERVICES_(HEALTHREPORT|SYNC)|NORMANDY|TELEMETRY_REPORTING)",[[:space:]]*)True\>/\1False/'
        '';

        meta = prevAttrs.meta or { } // {
          timeout = 24 * 3600;
          maxSilent = 8 * 3600;
        };
      };
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
        version = "0.26.1-unstable-2025-09-15";

        src = final.fetchFromGitHub {
          inherit (prevAttrs.src) owner repo;
          rev = "92fe011a9cc5e03a1c9a2127d33b603e6d24907e";
          hash = "sha256-VWbpRmt3XYXsHyXbv1NIW+sMzevxtOPKmyv6DRuatGo=";
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
      };

    } // lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
      xvfb-run = final.writeShellApplication {
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
