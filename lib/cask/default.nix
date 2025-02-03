{ lib }:
rec {
  cask' = import ./cask.nix { inherit lib; };
  cask = pkgs: source: (cask' pkgs (builtins.fromJSON (builtins.readFile source)));
  updateCask = import ./updateCask.nix;
  updateTap = import ./updateTap.nix;
  wrapCask = import ./wrapCask.nix { inherit lib; };
  tap = import ./tap.nix { inherit lib; };
}
