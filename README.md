# API


## Core
The core of wed is built around four main funtions, `mkRoot`, `mkNixos` (`mkDarwin` for macos), `mkUser`, and `mkModule` 

### wed.mkRoot
mkRoot is the entry point and where most of the magic happens, you should output the value of calling mkRoot to your flake's outputs
it expects just three options in the attrset you pass in; `modules`, `users`, and `hosts`
```nix
{ 
    outputs =
        { wed, ... }@inputs:
        wed.mkRoot inputs {
            modules = wed.import ./modules;
            hosts = wed.import ./hosts;
            users = wed.import ./users;
        };
}
```
from this, it will build up all of the `nixosConfigurations`, `darwinConfigurations`, and `homeManagerConfigurations` that you will need for all hosts and users.

users and hosts are generally one level deep, the name of the folder inside there being the hostname or username
1. `/hosts/hostname/default.nix`
2. `/users/username/default.nix`

modules can and should be many levels deep, as long as any leaf nodes nested under another leaf
`/modules/games/factorio/default.nix` for example can't exist under `/modules/games/default.nix`


### wed.mkNixos / wed.mkDarwin
These funtions will create a new host configuration in the final output


## Utilities
### wed.switch
will test all options in the attrset and select the one that matches the best 
on an aarch64 linux we will get webcord, x86_64 linux will get armcord, all darwin hosts will get discord regadless of arch 
```nix
{
    home.packages = let 
        pkg = wed.switch pkgs.system {
            darwin = {}: pkg.discord;
            linux = {}: pkg.armcord;
            aarch64-linux = {}: pkg.webcord;
        };
    in [ pkg ];
}
```

this lets you select platform spesific packages or even configuration if needed inside of home-manager confiurations,
for example 1password provides an ssh-agent but is at different paths in each system

```nix
{
  home =
    { pkgs, ... }:
    let
      socketPath = wed.switch pkgs.system {
        darwin = { ... }: "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
        linux = { ... }: "~/.1password/agent.sock";
      };
    in
    {
      config = {
        programs.ssh = {
          extraConfig = "IdentityAgent \"${socketPath}\"";
        };
      };
    };
}
```