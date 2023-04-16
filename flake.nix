{
  description = "A simple Nix-centric dotfiles deployer.";

  inputs.nixpkgs.url =
    "github:abstrnoah/nixpkgs/37c045276cbedf0651305c564e7b696df12bc5fc";

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
        {
          nixphile =
            nixpkgs.legacyPackages.${system}.concatTextFile {
              name = "nixphile";
              files = [ ./nixphile ];
              executable = true;
              destination = "/bin/nixphile";
            };
        }
      );
    };

}
