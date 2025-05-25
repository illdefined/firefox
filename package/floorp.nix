{ self, flocon, ... }: {
  lib,
  stdenv,
  wrapFirefox,
  floorp-unwrapped,
  writers,
}:

wrapFirefox (floorp-unwrapped.override {
  sndioSupport = false;

  inherit (self.packages.${stdenv.buildPlatform.system}) xvfb-run;
} |> flocon.lib.extendDrvAttrs {
  configureFlags =
    [ "--enable-default-toolkit=cairo-gtk3-wayland-only" ];
}) {
  extraPoliciesFiles =
    import ../policy.nix { inherit lib; firefox = true; }
      |> writers.writeJSON "policy.json"
      |> lib.singleton;
}
