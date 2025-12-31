{
  lib,
  stdenv,
  zig,
  xorg,
  freetype,
  fontconfig,
  pkg-config,
}:
stdenv.mkDerivation {
  pname = "goonwm";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [zig pkg-config];

  buildInputs = [
    xorg.libX11
    xorg.libXft
    xorg.libXinerama
    xorg.libXrender
    freetype
    fontconfig
  ];

  buildPhase = ''
    export HOME=$TMPDIR
    zig build -Doptimize=ReleaseSafe
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp zig-out/bin/goonwm $out/bin/
  '';

  meta = {
    description = "Dynamic window manager written in Zig, inspired by dwm";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "goonwm";
  };
}
