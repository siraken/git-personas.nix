{
  description = "home-manager module for per-client git configuration, generated at activation time";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
    }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      homeModules = {
        default = ./modules/git-clients.nix;
        gitClients = ./modules/git-clients.nix;
      };

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          # Builds a throwaway generation with the module enabled: type-checks
          # the options and runs shellcheck over both generators.
          example =
            (home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              modules = [
                self.homeModules.default
                {
                  home = {
                    username = "example";
                    homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/example" else "/home/example";
                    stateVersion = "24.11";
                  };

                  programs.git.enable = true;

                  programs.gitClients = {
                    enable = true;
                    clientsFile = "/nonexistent/clients.json";
                  };
                }
              ];
            }).activationPackage;
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
