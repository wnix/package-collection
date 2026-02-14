{
  lib,
  fetchFromGitHub,
  buildGoModule,
  buildNpmPackage,
  runCommand,
  jq,
}:

let
  version = "1.58.0";

  src = fetchFromGitHub {
    owner = "seatsurfing";
    repo = "seatsurfing";
    rev = "d8f02bc827912b4f39a432b77f0f64fcd2626bbf";
    hash = "sha256-6BU3UI0if35fJRmCTI83XvNfKKi9WpsuEVnQggT3q/s=";
  };

  # The upstream package-lock.json (npm 10 lockfile v3) omits `resolved` and
  # `integrity` fields for default-registry packages.  buildNpmPackage's
  # prefetch-npm-deps cannot download them without these fields.
  # We ship a regenerated lockfile with full metadata and patch it into the
  # source tree so both the FOD prefetch and the main build see it.
  uiSrc = runCommand "seatsurfing-ui-src" { } ''
    cp -r ${src}/ui $out
    chmod -R u+w $out
    cp ${./package-lock.json} $out/package-lock.json
  '';

  healthcheck = buildGoModule {
    pname = "seatsurfing-healthcheck";
    inherit version;
    src = "${src}/healthcheck";
    vendorHash = null;
    ldflags = [
      "-w"
      "-s"
    ];
  };
in
{
  server = buildGoModule {
    pname = "seatsurfing-server";
    inherit version src;
    modRoot = "server";
    vendorHash = "sha256-y2g60bmjNeprSlOcPWg8Bgv6XPvYyNfNvT23WdT2qn4=";

    env.CGO_ENABLED = 0;

    subPackages = [ "." ];

    ldflags = [
      "-w"
      "-s"
    ];

    # Tests require a running PostgreSQL database
    doCheck = false;

    postInstall = ''
      # Include healthcheck binary
      cp ${healthcheck}/bin/healthcheck $out/bin/

      # With modRoot = "server", cwd is inside server/ during postInstall
      mkdir -p $out/share/seatsurfing
      cp -r res $out/share/seatsurfing/
      cp ../version.txt $out/share/seatsurfing/
    '';

    meta = with lib; {
      description = "Seatsurfing backend server";
      homepage = "https://github.com/seatsurfing/seatsurfing";
      license = licenses.gpl3Only;
      mainProgram = "server";
    };
  };

  ui = buildNpmPackage {
    pname = "seatsurfing-ui";
    inherit version;
    src = uiSrc;

    npmDepsHash = "sha256-D/StWDzbxHxVlkR0pzHnwFzDS/H3A2q9IRx68SZxgtA=";
    npmFlags = [ "--legacy-peer-deps" ];
    makeCacheWritable = true;

    nativeBuildInputs = [ jq ];

    env = {
      NEXT_TELEMETRY_DISABLED = "1";
      NEXT_PUBLIC_PRODUCT_VERSION = version;
    };

    preBuild = ''
      bash ./add-missing-translations.sh
    '';

    postBuild = ''
      rm -rf build/cache
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r build/* $out/
      runHook postInstall
    '';

    dontNpmInstall = true;

    meta = with lib; {
      description = "Seatsurfing web UI (admin + booking)";
      homepage = "https://github.com/seatsurfing/seatsurfing";
      license = licenses.gpl3Only;
    };
  };
}
