{
  description = "Custom Nix packages and NixOS modules";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
  };

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
    in
    {
      # -- Packages --
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          seatsurfing = pkgs.callPackage ./pkgs/seatsurfing { };
        in
        {
          seatsurfing-server = seatsurfing.server;
          seatsurfing-ui = seatsurfing.ui;
        }
      );

      # -- NixOS modules --
      nixosModules = {
        seatsurfing = import ./modules/seatsurfing self;
      };

      # -- Flake checks (used by CI) --
      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          seatsurfing = pkgs.callPackage ./pkgs/seatsurfing { };
        in
        {
          seatsurfing-server = seatsurfing.server;
          seatsurfing-ui = seatsurfing.ui;
        }
      );
    };
}
