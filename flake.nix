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
  in {
    packages = lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: let
      pkgs = nixpkgs.legacyPackages.${system}.pkgsMusl;
      mimalloc = pkgs.mimalloc.override { secureBuild = true; };
    in {
      default = self.packages.${system}.firefox;
      firefox = (pkgs.wrapFirefox self.packages.${system}.firefox-unwrapped {
        extraPoliciesFiles = [ ./policy.nix ];
      }).overrideAttrs (prevAttrs: {
        buildCommand = prevAttrs.buildCommand + ''
          sed -i \
            -e '$i export MIMALLOC_PURGE_DELAY=150' \
            -e '$i export MIMALLOC_PURGE_DECOMMITS=0' \
            -e '$i export MIMALLOC_RESERVE_HUGE_OS_PAGES=2' \
            "$out/bin/firefox"
        '';
      });

      firefox-unwrapped = ((pkgs.buildMozillaMach {
        pname = "firefox";

        inherit (pkgs.firefox-beta-unwrapped)
          src version meta tests;

        extraConfigureFlags = [
          "--enable-default-toolkit=cairo-gtk3-wayland-only"
        ];

        extraBuildInputs = [ mimalloc ];
      }).overrideAttrs (prevAttrs: {
        env = prevAttrs.env or { } // {
          LDFLAGS = lib.toList prevAttrs.env.LDFLAGS or [ ] ++ [ "-lmimalloc" ] |> toString;
        };
      })).override {
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
    });

    hydraJobs = self.packages |> lib.foldlAttrs (jobs: system: packages: lib.recursiveUpdate jobs
      (lib.mapAttrs (name: package: { ${system} = package; }) packages)) { };
  };
}
