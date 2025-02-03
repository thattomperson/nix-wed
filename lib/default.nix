{ lib }:
{
  hasKey = key: set: lib.hasAttr key set;
  importers = import ./importers.nix { inherit lib; };
  cask = import ./cask { inherit lib; };

  modules =
    type: moduleConfigurations:
    (lib.lists.flatten (
      map (module: [
        module."${type}Module"
        module."${type}Modules"
      ]) moduleConfigurations
    ));
}
