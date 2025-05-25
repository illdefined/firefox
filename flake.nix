{
  description = "Custom Firefox build";

  inputs = {
    flocon.url = "git+https://woof.rip/mikael/flocon.git";
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.xz";
  };

  nixConfig = {
    extra-experimental-features = [ "pipe-operator" "ca-derivations" ];
    extra-substituters = [ "https://cache.kyouma.net" ];
    extra-trusted-public-keys = [ "cache.kyouma.net:Frjwu4q1rnwE/MnSTmX9yx86GNA/z3p/oElGvucLiZg=" ];
  };

  outputs = { flocon, ... }@inputs: flocon.lib.outputs inputs { path = ./.; };
}
