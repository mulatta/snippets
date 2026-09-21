{
  description = "snippets: bioinformatics workload stuffs.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      eachSystem =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f {
            inherit system;
            pkgs = nixpkgs.legacyPackages.${system};
          }
        );

      packageNames = builtins.attrNames (
        nixpkgs.lib.filterAttrs (_name: type: type == "directory") (builtins.readDir ./packages)
      );

      packages = eachSystem (
        { pkgs, ... }:
        nixpkgs.lib.genAttrs packageNames (
          pname: pkgs.callPackage (./packages + "/${pname}/package.nix") { }
        )
      );

      treefmtEval = eachSystem (
        { pkgs, ... }:
        treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          programs = {
            deadnix.enable = true;
            nixfmt.enable = true;
            statix.enable = true;
          };
          settings.formatter.nufmt = {
            command = nixpkgs.lib.getExe pkgs.nufmt;
            includes = [ "*.nu" ];
          };
        }
      );
    in
    {
      inherit packages;

      checks = eachSystem (
        { system, ... }:
        {
          formatting = treefmtEval.${system}.config.build.check self;
        }
      );

      devShells = eachSystem (
        { pkgs, ... }:
        {
          default = import ./devshell.nix { inherit pkgs; };
        }
      );

      formatter = eachSystem ({ system, ... }: treefmtEval.${system}.config.build.wrapper);
    };
}
