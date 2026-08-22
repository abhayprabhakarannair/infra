{lib, stdenvNoCC, fetchurl}:

stdenvNoCC.mkDerivation rec {
  pname = "herdr";
  version = "0.8.2";

  src = fetchurl {
    url = "https://github.com/herdrdev/herdr/releases/download/v${version}/herdr-linux-x86_64";
    hash = "sha256-3RUKFKSMGpgLHS0nS0fYLnNI5mDyAH8FQb2yM0b2PBc=";
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