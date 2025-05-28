{
  description = "Custom Firefox build";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  nixConfig = {
    extra-experimental-features = [ "pipe-operator" ];
    extra-substituters = [ "https://cache.kyouma.net" ];
    extra-trusted-public-keys = [ "cache.kyouma.net:Frjwu4q1rnwE/MnSTmX9yx86GNA/z3p/oElGvucLiZg=" ];
  };

  outputs = { self, nixpkgs, ... }: let
    inherit (nixpkgs) lib;

    meta = {
      timeout = 24 * 3600;
      maxSilent = 8 * 3600;
    };
  in {
    packages = lib.genAttrs [ "riscv64-linux" "aarch64-linux" "x86_64-linux" ] (system: let
      pkgs = nixpkgs.legacyPackages.${system};

      mimalloc = (pkgs.mimalloc.overrideAttrs (prevAttrs: {
        postPatch = prevAttrs.postPatch or "" + ''
        sed -E -i \
          -e 's/(\{ )1(, UNINIT, MI_OPTION_LEGACY\(purge_decommits,reset_decommits\) \})/\10\2/' \
          -e 's/(\{ )10(,  UNINIT, MI_OPTION_LEGACY\(purge_delay,reset_delay\) \})/\150\2/' \
          src/options.c
        '';
      })).override {
        secureBuild = true;
      };

      extraWrapper = prevAttrs: {
        buildCommand = prevAttrs.buildCommand + ''
          sed -i \
            -e '$i export LD_PRELOAD="${lib.getLib mimalloc}/lib/libmimalloc-secure.so"' \
            "$out/bin/${prevAttrs.meta.mainProgram}"
        '';
      };
    in {
      default = self.packages.${system}.floorp;
      floorp = (pkgs.wrapFirefox self.packages.${system}.floorp-unwrapped {
        extraPoliciesFiles =
          import ./policy.nix { inherit lib; firefox = true; }
          |> pkgs.writers.writeJSON "policy.json"
          |> lib.singleton;
      }).overrideAttrs extraWrapper;

      floorp-unwrapped = (pkgs.floorp-unwrapped.overrideAttrs (prevAttrs: {
        configureFlags = prevAttrs.configureFlags or [ ]
          ++ [ "--enable-default-toolkit=cairo-gtk3-wayland-only" ];

        meta = prevAttrs.meta // meta;
      })).override {
        #alsaSupport = false;
        ffmpegSupport = true;
        gssSupport = false;
        jackSupport = false;
        jemallocSupport = false;
        ltoSupport = true;
        pgoSupport = true;
        pipewireSupport = true;
        pulseaudioSupport = true;
        sndioSupport = false;
        waylandSupport = true;

        inherit (self.packages.${system}) xvfb-run;
      };

      thunderbird = (pkgs.wrapThunderbird self.packages.${system}.thunderbird-unwrapped {
        extraPoliciesFiles =
          import ./policy.nix { inherit lib; thunderbird = true; }
          |> pkgs.writers.writeJSON "policy.json"
          |> lib.singleton;
      }).overrideAttrs extraWrapper;

      thunderbird-unwrapped = (pkgs.thunderbird-latest-unwrapped.overrideAttrs (prevAttrs: {
        configureFlags = prevAttrs.configureFlags or [ ]
          ++ [ "--enable-default-toolkit=cairo-gtk3-wayland-only" ];

        meta = prevAttrs.meta // meta;
      })).override {
        #alsaSupport = false;
        ffmpegSupport = false;
        jackSupport = false;
        jemallocSupport = false;
        ltoSupport = true;
        pgoSupport = false;
        pipewireSupport = false;
        pulseaudioSupport = true;
        sndioSupport = false;
        waylandSupport = true;

        privacySupport = true;
        #drmSupport = false;

        inherit (self.packages.${system}) xvfb-run;
      };

      xvfb-run = pkgs.writeShellApplication {
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
            exec '${lib.getExe pkgs.cage}' -- "$@"
        '';

        # shellcheck is not yet available on RISC-V
        checkPhase = if pkgs.stdenv.buildPlatform.isRiscV then ''
          runHook preCheck
          ${pkgs.stdenv.shellDryRun} "$target"
          runHook postCheck
        '' else null;
      };
    });

    hydraJobs = self.packages |> lib.foldlAttrs (jobs: system: packages: lib.recursiveUpdate jobs
      (lib.mapAttrs (name: package: { ${system} = lib.hydraJob package; }) packages)) { };
  };
}
