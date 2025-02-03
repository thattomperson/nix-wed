name:
{ pkgs, lib, ... }:
let
  caskToJson = pkgs.writeScriptBin "cask-to-json" ''
    #! ${lib.getExe pkgs.ruby} -w
    ${builtins.readFile ./scripts/updateTap.rb}
  '';

  repo = "${builtins.head (lib.strings.splitString "/" name)}/homebrew-tap";
  branch = "main";
  filename = "${lib.lists.last (lib.strings.splitString "/" name)}.rb";
  url = "https://raw.githubusercontent.com/${repo}/refs/heads/${branch}/Casks/${filename}";
in
pkgs.writeShellApplication {
  name = "update-${builtins.replaceStrings [ "/" ] [ "-" ] name}";
  runtimeInputs = with pkgs; [ curl ];
  text = ''
    curl ${url} > ${filename};
    ${lib.getExe caskToJson} ./${filename} > source.json
  '';
}
