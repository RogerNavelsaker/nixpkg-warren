{
  description = "Nix packaging scaffold for Warren (CLI, Server, and Docker Image)";

  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://rogernavelsaker.cachix.org"
      "https://nacosolutions.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "rogernavelsaker.cachix.org-1:n1DtzMNhA9Rz4Kg3xlXOi/KceULu8VrMbs9WXyMFQNQ="
      "nacosolutions.cachix.org-1:JzCiW2CLcuLXtwOVAg3SlSK/kpqWbfSFEVenyKVUlug="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    bun2nix.url = "github:nix-community/bun2nix";
    bun2nix.inputs.nixpkgs.follows = "nixpkgs";

    pi-coding-agent.url = "github:RogerNavelsaker/nixpkg-pi-coding-agent";
    pi-coding-agent.inputs.nixpkgs.follows = "nixpkgs";
    pi-coding-agent.inputs.bun2nix.follows = "bun2nix";

    seeds.url = "github:RogerNavelsaker/nixpkg-seeds";
    seeds.inputs.nixpkgs.follows = "nixpkgs";
    seeds.inputs.bun2nix.follows = "bun2nix";

    mulch.url = "github:RogerNavelsaker/nixpkg-mulch";
    mulch.inputs.nixpkgs.follows = "nixpkgs";
    mulch.inputs.bun2nix.follows = "bun2nix";

    terrarium.url = "github:RogerNavelsaker/nixpkg-terrarium";
    terrarium.inputs.nixpkgs.follows = "nixpkgs";
    terrarium.inputs.bun2nix.follows = "bun2nix";

    trellis.url = "github:RogerNavelsaker/nixpkg-trellis";
    trellis.inputs.nixpkgs.follows = "nixpkgs";
    trellis.inputs.bun2nix.follows = "bun2nix";
  };

  outputs = {
    self,
    nixpkgs,
    bun2nix,
    pi-coding-agent,
    seeds,
    mulch,
    terrarium,
    trellis,
    ...
  }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ bun2nix.overlays.default ];
          config.allowUnfree = true;
        };
      });
    in {
      packages = forAllSystems ({ pkgs }:
        let
          warrenPackages = pkgs.callPackage ./nix/package.nix { };
          dockerImage = pkgs.callPackage ./nix/docker.nix {
            inherit (warrenPackages) server;
          };
          agentImage = pkgs.callPackage ./nix/agent-docker.nix {
            piPackage = pi-coding-agent.packages.${pkgs.system}.default.pi;
            seedsPackage = seeds.packages.${pkgs.system}.default.sd;
            mulchPackage = mulch.packages.${pkgs.system}.default.ml;
            terrariumPackage = terrarium.packages.${pkgs.system}.default.tr;
            trellisPackage = trellis.packages.${pkgs.system}.default.tl;
          };
        in {
          default = warrenPackages.cli;
          cli = warrenPackages.cli;
          server = warrenPackages.server;
          dockerImage = dockerImage;
          agentImage = agentImage;
        }
      );

      apps = forAllSystems ({ pkgs }: {
        default = {
          type = "app";
          program = "${self.packages.${pkgs.system}.cli}/bin/warren";
        };
        cli = {
          type = "app";
          program = "${self.packages.${pkgs.system}.cli}/bin/warren";
        };
        server = {
          type = "app";
          program = "${self.packages.${pkgs.system}.server}/bin/warren-server";
        };
      });

      devShells = forAllSystems ({ pkgs }: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            bun
            bun2nix
            jq
            nixfmt-rfc-style
            skopeo
          ];
        };
      });
    };
}
