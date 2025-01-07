{
  description = "Custom Firefox build";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  nixConfig = {
    extra-experimental-features = [ "pipe-operator" "pipe-operators" ];
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
        cmakeFlags = let
          cppdefs = {
            MI_DEFAULT_EAGER_COMMIT = 0;
            MI_DEFAULT_ALLOW_LARGE_OS_PAGES = 1;
          } |> lib.mapAttrsToList (name: value: "${name}=${toString value}")
            |> lib.concatStringsSep ";";
        in prevAttrs.cmakeFlags ++ [ ''-DMI_EXTRA_CPPDEFS="${cppdefs}"'' ];
      })).override {
        secureBuild = true;
      };

      extraWrapper = prevAttrs: {
        buildCommand = prevAttrs.buildCommand + ''
          sed -i \
            -e '$i export MIMALLOC_PURGE_DELAY=150' \
            -e '$i export MIMALLOC_RESERVE_HUGE_OS_PAGES=2' \
            -e '$i export LD_PRELOAD="${lib.getLib mimalloc}/lib/libmimalloc-secure.so"' \
            "$out/bin/${prevAttrs.meta.mainProgram}"
        '';
      };

      wrapFirefox = pkgs.wrapFirefox.override {
        ffmpeg = pkgs.ffmpeg.override {
          ffmpegVariant = "headless";

          withAlsa = false;
          withAom = false;
          withCodec2 = true;
          withGnutls = false;
          withSsh = false;
          withV4l2 = false;

          withNetwork = false;
          withBin = false;
          withLib = true;
          withDocumentation = false;
          withStripping = true;
        };
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

      firefox = (pkgs.wrapFirefox self.packages.${system}.firefox-unwrapped {
        extraPoliciesFiles =
          import ./policy.nix { inherit lib; firefox = true; }
          |> pkgs.writers.writeJSON "policy.json"
          |> lib.singleton;
      }).overrideAttrs extraWrapper;

      firefox-unwrapped = (pkgs.buildMozillaMach {
        pname = "firefox";
        inherit (pkgs.firefox-beta-unwrapped)
          src version tests;

        extraConfigureFlags = [ "--enable-default-toolkit=cairo-gtk3-wayland-only" ];

        meta = pkgs.firefox-beta-unwrapped.meta // meta;
      }).override {
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

        crashreporterSupport = false;
        googleAPISupport = false;

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
