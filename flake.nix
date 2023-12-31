{
  description = "My flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager }: {
    mkNixos = config:
      let
        args = inputs // { lib = self; } // (config.specialArgs or { });
        modules = map (module: import module args) config.modules;
        nixosModules = nixpkgs.lib.flatten (map
          (module: [ module.nixosModules.default ] ++ module.nixosModules.extra)
          modules);
        homeManagerModules = nixpkgs.lib.flatten (map (module:
          [ module.homeManagerModules.default ]
          ++ module.homeManagerModules.extra) modules);
      in nixpkgs.lib.nixosSystem {
        system = config.system or "x86_64-linux";
        specialArgs = config.specialArgs or { };
        modules = [
          {
            networking.hostName = config.name;
            system.stateVersion = config.stateVersion or "23.11";
            profiles = config.profiles or { };
          }
          home-manager.nixosModules.home-manager
          {
            home-manager.sharedModules = homeManagerModules;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
        ] ++ nixpkgs.lib.forEach config.users (user: {
          users.users."${user.name}" = {
            isNormalUser = true;
            name = user.name;
            home = user.home or "/home/${user.name}";
            extraGroups = user.groups or [ ];
            initialPassword = "password";
          };
          home-manager.users."${user.name}" = {
            home.stateVersion = user.stateVersion or "23.11";
            profiles = user.profiles or { };
          };
        }) ++ nixosModules ++ (map (path: import path) config.imports);
      };

    mkProfile = name: profile: {
      nixosModules.extra = profile.extraNixosModules or [ ];
      nixosModules.default = { config, lib, pkgs, ... }@input:
        with lib;
        let
          cfg = config.profiles."${name}";
          usersKey = attrNames config.home-manager.users;
          usersSet = config.home-manager.users;
          usersList = map (key: getAttr key usersSet) usersKey;
          enableDefault = foldl' (x: y: x || y) false
            (map (user: user.profiles."${name}".enable) usersList);
          enableUsers =
            filter (user: usersSet."${user}".profiles."${name}".enable)
            usersKey;
        in {
          options.profiles."${name}" = {
            enable = mkOption {
              type = types.bool;
              default = enableDefault;
              description = ''
                Enable the ${name} profile
              '';
            };
          };
          config = mkIf cfg.enable (if profile ? nixos then
            profile.nixos (input // { users = enableUsers; })
          else
            { });
        };
      darwinModules.default = { config, lib, pkgs, ... }@input:
        with lib;
        let
          cfg = config.profiles."${name}";
          usersSet = config.home-manager.users;
          usersList = (map (key: getAttr key usersSet) (attrNames usersSet));
          enableDefault = foldl' (x: y: x || y) false
            (map (user: user.profiles."${name}".enable) usersList);
        in {
          options.profiles."${name}" = {
            enable = mkOption {
              type = types.bool;
              default = enableDefault;
              description = ''
                Enable the ${name} profile
              '';
            };
          };
          config = mkIf cfg.enable
            (if profile ? darwin then profile.darwin input else { });
        };
      homeManagerModules.extra = profile.extraHomeManagerModules or [ ];
      homeManagerModules.default = { config, lib, pkgs, ... }@input:
        with lib;
        let cfg = config.profiles."${name}";
        in {
          options.profiles."${name}" = {
            enable = mkOption {
              type = types.bool;
              default = false;
              description = ''
                Enable the ${name} profile
              '';
            };
          };
          config = mkIf cfg.enable
            (if profile ? home then profile.home input else { });
        };
    };
  };
}
