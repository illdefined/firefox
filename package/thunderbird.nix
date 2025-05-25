{ self, flocon, ... }: {
  lib,
  stdenv,
  wrapThunderbird,
  thunderbird-unwrapped,
  writers,
}:

wrapThunderbird (thunderbird-unwrapped.override {
  ffmpegSupport = false;
  pgoSupport = false;
  pipewireSupport = false;
  sndioSupport = false;

  inherit (self.packages.${stdenv.buildPlatform.system}) xvfb-run;
} |> flocon.lib.extendDrvAttrs {
  configureFlags =
    [ "--enable-default-toolkit=cairo-gtk3-wayland-only" ];
}) {
  extraPoliciesFiles =
    import ../policy.nix { inherit lib; thunderbird = true; }
      |> writers.writeJSON "policy.json"
      |> lib.singleton;
}
