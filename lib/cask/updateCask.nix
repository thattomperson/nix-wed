name:
{ pkgs, lib, ... }:
lib.getExe (
  pkgs.writeShellApplication {
    name = "update-${name}";
    runtimeInputs = with pkgs; [
      curl
      jq
    ];
    text = ''
      curl https://formulae.brew.sh/api/cask/${name}.json | jq 'with_entries(select([.key] | inside(["url", "sha256", "artifacts", "desc", "homepage", "version", "name"])))' > source.json;
    '';
  }
)
