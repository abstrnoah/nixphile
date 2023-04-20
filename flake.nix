{
  description = "A simple Nix-centric dotfiles deployer.";

  # TODO Probably can remove nixpkgs entirely if I replicate concatTextFile.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";

  outputs =
    { self, nixpkgs }:
    let
      supported_systems = [ "x86_64-linux" "armv7l-linux" ];
      gen_set = f: builtins.foldl' (a: h: a // { "${h}" = f h; }) {};
      for_all_systems = f: gen_set f supported_systems;
    in
    {
      packages = for_all_systems (
        system:
        rec {
          nixphile =
            nixpkgs.legacyPackages.${system}.concatTextFile {
              name = "nixphile";
              files = [ ./nixphile ];
              executable = true;
              destination = "/bin/nixphile";
            };

          default = nixphile;
        }
      );
    };

}
