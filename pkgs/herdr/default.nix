{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "herdr";
  version = "0.8.2";

  src = fetchurl {
    url = "https://github.com/herdrdev/herdr/releases/download/v${version}/herdr-linux-x86_64";
    hash = "sha256-l2FQoU1JDJSyQ+ouGn6y37Z/EuNrGC25CTb2co5q7PQ=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -m755 -D $src $out/bin/herdr
    runHook postInstall
  '';

  meta = with lib; {
    description = "An opinionated, open-source tool for managing private AI agents";
    homepage = "https://herdr.dev";
    license = licenses.bsd3;
    platforms = ["x86_64-linux"];
    maintainers = [];
    mainProgram = "herdr";
  };
}
