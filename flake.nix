{
  description = "goonwm - A dynamic window manager written in Zig";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs = {
    self,
    nixpkgs,
  }: let
    systems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = fn: nixpkgs.lib.genAttrs systems (system: fn nixpkgs.legacyPackages.${system});
  in {
    packages = forAllSystems (pkgs: rec {
      default = pkgs.callPackage ./default.nix {};
      goonwm = default;
    });

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        packages = [
          pkgs.zig
          pkgs.zls
          pkgs.just
          pkgs.alacritty
          pkgs.st
          pkgs.xorg.xorgserver
          pkgs.xorg.libX11
          pkgs.xorg.libXft
          pkgs.xorg.libXinerama
          pkgs.xorg.libXrender
          pkgs.freetype
          pkgs.fontconfig
          pkgs.pkg-config
          pkgs.valgrind
        ];
        shellHook = ''
          export PS1="(goonwm-dev) $PS1"
        '';
      };
    });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}
