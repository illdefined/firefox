{
  description = "Custom Firefox build";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    neoidiosyn = {
      url = "git+https://woof.rip/mikael/neoidiosyn.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-experimental-features = [ "pipe-operator" "pipe-operators" ];
    extra-substituters = [ "https://cache.kyouma.net" ];
    extra-trusted-public-keys = [ "cache.kyouma.net:Frjwu4q1rnwE/MnSTmX9yx86GNA/z3p/oElGvucLiZg=" ];
  };

  outputs = { self, nixpkgs, neoidiosyn, ... }: let
    inherit (nixpkgs) lib;
  in {
    packages = lib.mapAttrs (system: pkgs: let
      extraWrapper = prevAttrs: {
        buildCommand = prevAttrs.buildCommand + ''
          sed -i \
            -e '$i export MIMALLOC_PURGE_DELAY=150' \
            -e '$i export MIMALLOC_RESERVE_HUGE_OS_PAGES=2' \
            "$out/bin/${prevAttrs.meta.mainProgram}"
        '';
      };

      wrapFirefox = pkgs.wrapFirefox.override {
        ffmpeg = pkgs.ffmpeg.override {
          ffmpegVariant = "headless";

          withAlsa = false;
          withAom = false;
          withCodec2 = true;
          withDrm = false;
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
      default = self.packages.${system}.firefox;
      firefox = (pkgs.wrapFirefox self.packages.${system}.firefox-unwrapped {
        extraPoliciesFiles =
          import ./policy.nix { inherit lib; firefox = true; }
          |> pkgs.writers.writeJSON "policy.json"
          |> lib.singleton;
      }).overrideAttrs extraWrapper;

      firefox-unwrapped = ((pkgs.buildMozillaMach {
        pname = "firefox";
        inherit (pkgs.firefox-beta-unwrapped)
          src version meta tests;

        extraConfigureFlags = [ "--enable-default-toolkit=cairo-gtk3-wayland-only" ];      
      }).overrideAttrs {
        autoVarInit = "zero";
        boundsCheck = true;
      }).override {
        alsaSupport = false;
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
      };

      thunderbird = (pkgs.wrapThunderbird self.packages.${system}.thunderbird-unwrapped {
        extraPoliciesFiles =
          import ./policy.nix { inherit lib; thunderbird = true; }
          |> pkgs.writers.writeJSON "policy.json"
          |> lib.singleton;
      }).overrideAttrs extraWrapper;

      thunderbird-unwrapped = (pkgs.thunderbird-latest-unwrapped.overrideAttrs (prevAttrs: {
        autoVarInit = "zero";
        boundsCheck = true;

        configureFlags = prevAttrs.configureFlags or [ ]
          ++ [ "--enable-default-toolkit=cairo-gtk3-wayland-only" ];
      })).override {
        alsaSupport = false;
        ffmpegSupport = false;
        gssSupport = false;
        jackSupport = false;
        jemallocSupport = false;
        ltoSupport = true;
        pgoSupport = true;
        pipewireSupport = false;
        pulseaudioSupport = false;
        sndioSupport = false;
        waylandSupport = true;

        privacySupport = true;
        drmSupport = false;
      };
    }) neoidiosyn.legacyPackages;

    hydraJobs = self.packages |> lib.foldlAttrs (jobs: system: packages: lib.recursiveUpdate jobs
      (lib.mapAttrs (name: package: { ${system} = lib.hydraJob package; }) packages)) { };
  };
}
