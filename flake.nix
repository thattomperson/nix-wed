{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-root.url = "github:srid/flake-root";
    flake-parts.url = "github:hercules-ci/flake-parts";
    just-flake.url = "github:juspay/just-flake";
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs-stable.follows = "nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-24.05-darwin";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    nixpak = {
      url = "github:nixpak/nixpak";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpak-pkgs = {
      url = "github:nixpak/pkgs";
      inputs.nixpak.follows = "nixpak";
    };
  };
  outputs =
    {
      self,
      flake-parts,
      nixpkgs,
      nix-darwin,
      nixpak-pkgs,
      git-hooks-nix,
      home-manager,
      ...
    }@wedInputs:
    let
      inherit (nixpkgs) lib;
      wed-lib = import ./lib { inherit lib; };
      attrsets = lib.attrsets;
      strings = lib.strings;
    in
    {
      mkRoot =
        inputs: config:
        let
          args = inputs // {
            wed = self;
          };

          moduleConfigurations = attrsets.attrValues (
            attrsets.mapAttrs (name: path: import path args (strings.splitString "." name)) config.modules
          );

          nixosModules = wed-lib.modules "nixos" moduleConfigurations;
          darwinModules = wed-lib.modules "darwin" moduleConfigurations;
          homeManagerModules = wed-lib.modules "homeManager" moduleConfigurations;
          flakeModules = wed-lib.modules "flake" moduleConfigurations;
          overlays' = (
            lib.lists.flatten (
              map (module: [
                module.overlay
                module.overlays
              ]) moduleConfigurations
            )
          );
          # overlays' = wed-lib.modules "overlays" moduleConfigurations;

          userConfigurations = attrsets.mapAttrs (name: path: import path args name) config.users;
          nixosUserModules = attrsets.attrValues (
            attrsets.mapAttrs (name: config: config.nixosModule) userConfigurations
          );
          darwinUserModules = attrsets.attrValues (
            attrsets.mapAttrs (name: config: config.darwinModule) userConfigurations
          );

          overlays = [
            (final: prev: {
              unstable = import wedInputs.nixpkgs-unstable {
                system = final.system;
                config.allowUnfree = final.config.allowUnfree;
              };
            })
          ] ++ overlays';

          hostConfigurations = attrsets.mapAttrs (name: path: import path args name) config.hosts;
          nixosHostConfigurations = attrsets.filterAttrs (n: v: v.type == "nixos") hostConfigurations;
          nixosConfigurations = attrsets.mapAttrs (
            name: hostConfiguration:
            hostConfiguration.config {
              inherit inputs homeManagerModules overlays;
              nixosModules = (nixosModules ++ nixosUserModules);
            }
          ) nixosHostConfigurations;

          darwinHostConfigurations = attrsets.filterAttrs (n: v: v.type == "darwin") hostConfigurations;
          darwinConfigurations = attrsets.mapAttrs (
            name: hostConfiguration:
            hostConfiguration.config {
              inherit inputs homeManagerModules overlays;
              darwinModules = (darwinModules ++ darwinUserModules);
            }
          ) darwinHostConfigurations;
        in
        flake-parts.lib.mkFlake { inputs = (inputs // wedInputs); } {
          imports = [
            wedInputs.just-flake.flakeModule
            wedInputs.flake-root.flakeModule
            flake-parts.flakeModules.easyOverlay
            git-hooks-nix.flakeModule
            # "${nixpak-pkgs}/part.nix"
            # "${nixpak-pkgs}/modules/builders.nix"
          ] ++ flakeModules;
          systems = [
            "aarch64-linux"
            "x86_64-linux"
            "aarch64-darwin"
            "x86_64-darwin"
          ];
          flake = {
            nixosConfigurations = nixosConfigurations;
            darwinConfigurations = darwinConfigurations;
          };
          perSystem =
            {
              config,
              lib,
              pkgs,
              system,
              ...
            }:
            {
              config = {
                _module.args.pkgs = import inputs.nixpkgs {
                  inherit system;
                  overlays =
                    with inputs;
                    [
                      (final: _prev: {
                        # Make unstable nixpkgs accessible through 'pkgs.unstable'
                        unstable = import nixpkgs-unstable {
                          system = final.system;
                          config.allowUnfree = final.config.allowUnfree;
                        };
                      })
                    ]
                    ++ (config.overlays or [ ]);
                };

                pre-commit = {
                  check.enable = true;
                  settings.hooks = {
                    nixfmt-rfc-style.enable = true;
                    biome.enable = true;
                  };
                };

                just-flake.package = pkgs.unstable.just;
                just-flake.modules = {
                  update = {
                    modules.input = {
                      features = {
                        all = {
                          enable = true;
                          justfile = ''
                            # Update all inputs 
                            [no-cd]
                            all:
                              nix flake update
                          '';
                        };
                      };
                    };
                  };
                  make = {
                    enable = true;
                    features = {
                      user = {
                        enable = true;
                        justfile = ''
                          [no-cd]
                          user name:
                            mkdir -p "users/{{ replace(name, '.', '/') }}";
                            cp ${./stubs/user/default.nix} "users/{{ replace(name, '.', '/') }}/default.nix";
                        '';
                      };
                      module = {
                        enable = true;
                        justfile = ''
                          [no-cd]
                          module name:
                            mkdir -p "modules/{{ replace(name, '.', '/') }}";
                            cp ${./stubs/module/default.nix} "modules/{{ replace(name, '.', '/') }}/default.nix";
                        '';
                      };
                      nixos = {
                        enable = true;
                        justfile = ''
                          [no-cd]
                          nixos name:
                            mkdir -p "hosts/{{ replace(name, '.', '/') }}";
                            cp ${./stubs/host/nixos.nix} "hosts/{{ replace(name, '.', '/') }}/default.nix";
                        '';
                      };
                      darwin = {
                        enable = true;
                        justfile = ''
                          [no-cd]
                          darwin name:
                            mkdir -p "hosts/{{ replace(name, '.', '/') }}";
                            cp ${./stubs/host/darwin.nix} "hosts/{{ replace(name, '.', '/') }}/default.nix";
                        '';
                      };
                    };
                  };
                  os = {
                    enable = true;
                    features = {
                      build = {
                        enable = true;
                        justfile = ''
                          # Build the current host's config and symlink it to ./result
                          [no-cd]
                          [macos]
                          build:
                            darwin-rebuild build --flake $FLAKE_ROOT

                          [no-cd]
                          [linux]
                          build:
                            nixos-rebuild build --flake $FLAKE_ROOT
                        '';
                      };
                      switch = {
                        enable = true;
                        justfile = ''
                          # Build the current host's config, set it as the default for next boot, and enable it now
                          [no-cd]
                          [macos]
                          switch:
                            darwin-rebuild switch --flake $FLAKE_ROOT

                          [no-cd]
                          [linux]
                          switch:
                            sudo nixos-rebuild switch --flake $FLAKE_ROOT
                        '';
                      };
                      boot = {
                        enable = true;
                        justfile = ''
                          # Build the current host's config, set it as the default for next boot but don't enable it now
                          [no-cd]
                          [macos]
                          boot:
                            darwin-rebuild boot --flake $FLAKE_ROOT

                          [no-cd]
                          [linux]
                          boot:
                            sudo nixos-rebuild boot --flake $FLAKE_ROOT
                        '';
                      };
                      test = {
                        enable = true;
                        justfile = ''
                          # Build the current host's config and enable it now
                          [no-cd]
                          [linux]
                          test:
                            sudo nixos-rebuild test --flake $FLAKE_ROOT
                        '';
                      };
                      diff = {
                        enable = true;
                        justfile = ''
                          # Build the current host's config, and print what packages changed since the current running version
                          [no-cd]
                          diff: build
                            nix store diff-closures /var/run/current-system ./result
                        '';
                      };
                    };
                  };
                };
                just-flake.features = {
                  update-modules = {
                    enable = true;
                    justfile = ''
                      update-modules:
                        just --list | grep 'update-module-' | xargs -n1 just
                    '';
                  };
                  repl = {
                    enable = true;
                    justfile = ''
                      repl:
                        nix repl --extra-experimental-features 'flakes eval-flake' .
                    '';
                  };
                };

                formatter = pkgs.nixfmt-rfc-style;
                devShells.default = pkgs.mkShell {
                  buildInputs = with pkgs; [ convco ];
                  inputsFrom = [
                    config.just-flake.outputs.devShell
                    config.flake-root.devShell
                    config.pre-commit.devShell
                  ];
                };
              };
            };
        };

      mkDarwin = callable: hostname: {
        type = "darwin";
        config =
          {
            inputs,
            darwinModules,
            homeManagerModules,
            overlays,
          }:
          nix-darwin.lib.darwinSystem {
            specialArgs = inputs;
            modules =
              [
                {
                  nixpkgs.overlays = overlays;
                  networking.hostName = hostname;
                  home-manager.sharedModules = homeManagerModules;
                  home-manager.useGlobalPkgs = true;
                  home-manager.useUserPackages = true;
                  home-manager.extraSpecialArgs = inputs;
                }
                home-manager.darwinModules.home-manager
              ]
              ++ darwinModules
              ++ [ (callable inputs) ];
          };
      };

      mkNixos = callable: hostname: {
        type = "nixos";
        config =
          {
            inputs,
            nixosModules,
            homeManagerModules,
            overlays,
          }:
          nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = inputs;
            modules =
              [
                {
                  nixpkgs.overlays = overlays;
                  networking.hostName = hostname;
                  system.stateVersion = "24.05";
                  modules = { };
                  home-manager.sharedModules = homeManagerModules;
                  home-manager.useGlobalPkgs = true;
                  home-manager.useUserPackages = true;
                  home-manager.extraSpecialArgs = inputs;
                }
                home-manager.nixosModules.home-manager
              ]
              ++ nixosModules
              ++ [ (callable inputs) ];
          };
      };

      mkModule = module: name: {
        name = name;
        overlay = module.overlay or (final: prev: { });
        overlays = module.overlays or [ ];
        nixosModules = module.nixosModules or [ ];
        nixosModule =
          {
            config,
            lib,
            pkgs,
            ...
          }@inputs:
          let
            users = attrsets.filterAttrs (
              username: user: (attrsets.getAttrFromPath name user.modules).enable
            ) config.home-manager.users;
            cfg = attrsets.getAttrFromPath name config.modules;

            nixosModule = (module.nixos or ({ ... }: { })) (
              inputs
              // {
                cfg = cfg;
                users = users;
              }
            );
          in
          {
            options.modules = attrsets.setAttrByPath name (
              (nixosModule.options or { })
              // {
                enable = lib.mkOption {
                  default = (lib.lists.length (attrsets.attrValues users)) > 0;
                  example = true;
                  description = "Whether to enable ${strings.concatStringsSep "." name}.";
                  type = lib.types.bool;
                };
              }
            );
            # config = {};
            config = lib.mkIf cfg.enable (nixosModule.config or { });
          };
        darwinModules = module.darwinModules or [ ];
        darwinModule =
          {
            config,
            lib,
            pkgs,
            ...
          }@inputs:
          let
            users = attrsets.filterAttrs (
              username: user: (attrsets.getAttrFromPath name user.modules).enable
            ) config.home-manager.users;
            cfg = attrsets.getAttrFromPath name config.modules;

            darwinModule = (module.darwin or ({ ... }: { })) (
              inputs
              // {
                cfg = cfg;
                users = users;
              }
            );
          in
          {
            options.modules = attrsets.setAttrByPath name (
              (darwinModule.options or { })
              // {
                enable = lib.mkOption {
                  default = (lib.lists.length (attrsets.attrValues users)) > 0;
                  example = true;
                  description = "Whether to enable ${strings.concatStringsSep "." name}.";
                  type = lib.types.bool;
                };
              }
            );
            # config = {};
            config = lib.mkIf cfg.enable (darwinModule.config or { });
          };
        homeManagerModules = module.homeManagerModules or [ ];
        homeManagerModule =
          {
            config,
            lib,
            pkgs,
            ...
          }@inputs:
          let
            cfg = attrsets.getAttrFromPath name config.modules;
            homeManagerModule = (module.home or ({ ... }: { })) (inputs // { cfg = cfg; });
          in
          {
            options.modules = attrsets.setAttrByPath name (
              (homeManagerModule.options or { })
              // {
                enable = lib.mkOption {
                  default = false;
                  example = true;
                  description = "Whether to enable ${strings.concatStringsSep "." name}.";
                  type = lib.types.bool;
                };
              }
            );
            # config = {};
            config = lib.mkIf cfg.enable (homeManagerModule.config or { });
          };
        flakeModules = module.flakeModules or [ ];
        flakeModule = {
          perSystem =
            {
              config,
              pkgs,
              lib,
              ...
            }@inputs:
            {
              config =
                let
                  # cfg = attrsets.getAttrFromPath name config.modules;
                  # feature-name = "update-module-${strings.concatStringsSep "-" name}";
                  folder = (lib.lists.sublist 0 ((lib.lists.length name) - 1) name);
                  feature-name = lib.lists.last name;
                  folder-path = strings.concatStringsSep ".modules." folder;
                  feature-path = strings.splitString "." "${folder-path}.features.${feature-name}";
                in
                {
                  just-flake.modules.update.enable = true;
                  just-flake.modules.update.modules.module.enable = true;
                  just-flake.modules.update.modules.module.modules = attrsets.setAttrByPath feature-path {
                    enable = wed-lib.hasKey "updateScript" module;
                    justfile = ''
                      [no-cd]
                      ${feature-name}:
                        echo "Updating module ${strings.concatStringsSep "/" name}"
                        cd "modules/${strings.concatStringsSep "/" name}" && ${(module.updateScript inputs)};
                        git add "modules/${strings.concatStringsSep "/" name}";
                        pre-commit || true;
                        git add "modules/${strings.concatStringsSep "/" name}";
                        git commit -m "chore(modules): update module ${strings.concatStringsSep "/" name}";
                    '';
                  };
                };
            };
        };
      };

      mkUser = module: username: {
        nixosModule =
          {
            config,
            lib,
            pkgs,
            ...
          }@inputs:
          let
            cfg = config.wed.users."${username}";
            user = (module inputs);
          in
          {
            options.wed.users."${username}" = {
              enable = lib.mkOption {
                default = false;
                example = true;
                description = "Whether to enable ${username}.";
                type = lib.types.bool;
              };
            };
            config = lib.mkIf cfg.enable {
              users.users."${user.name or username}" = {
                name = user.name or username;
                home = "/home/${user.name or username}";
                isNormalUser = true;
                extraGroups = user.groups or [ ];
                initialPassword = "password";
              };
              home-manager.users."${user.name or username}" = {
                home.stateVersion = user.stateVersion or "24.05";
                modules = user.modules or { };
                home.file.".face" = {
                  enable = true;
                  source = user.profile;
                };
              };
              system.activationScripts."copy${username}Profile" = lib.stringAfter [ "var" ] ''
                mkdir -p /var/lib/AccountsService/icons;
                cp /home/${user.name or username}/.face /var/lib/AccountsService/icons/${username};
              '';
            };
          };
        darwinModule =
          {
            config,
            lib,
            pkgs,
            ...
          }@inputs:
          let
            cfg = config.wed.users."${username}";
            user = (module inputs);
          in
          {
            options.wed.users."${username}" = {
              enable = lib.mkOption {
                default = false;
                example = true;
                description = "Whether to enable ${username}.";
                type = lib.types.bool;
              };
            };
            config = lib.mkIf cfg.enable {
              users.users."${user.name or username}" = {
                name = user.name or username;
                home = "/Users/${user.name or username}";
              };
              home-manager.users."${user.name or username}" = {
                home.stateVersion = user.stateVersion or "24.05";
                modules = user.modules or { };
              };
            };
          };
      };

      import = dir: wed-lib.importers.flattenTree (wed-lib.importers.rakeLeaves dir);

      switch =
        system: config:
        let
          prefixes = [
            ""
            "aarch64-"
            "x86_64-"
          ];
          configNames = (builtins.map (prefix: (lib.strings.removePrefix prefix system)) prefixes);
          configName = builtins.head (builtins.filter (x: (wed-lib.hasKey x config)) configNames);
        in
        (config."${configName}" { });

      cask = wed-lib.cask.cask;
      wrapCask = wed-lib.cask.wrapCask;
      updateCask = wed-lib.cask.updateCask;
      updateTap = wed-lib.cask.updateTap;
      updateFlakeInput =
        name:
        { pkgs, ... }:
        pkgs.writeShellApplication {
          name = "update-${name}";
          text = ''
            nix flake lock --update-input "${name}"
          '';
        };
    };
}
