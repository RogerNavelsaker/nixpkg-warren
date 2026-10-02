{
  bash,
  bun2nix,
  installShellFiles,
  lib,
  stdenv,
  symlinkJoin,
  makeWrapper,
  bun,
  git,
  cacert,
  docker-client,
}:

let
  manifest = builtins.fromJSON (builtins.readFile ./package-manifest.json);
  packageVersion =
    manifest.package.version
    + lib.optionalString (manifest.package ? packageRevision) "-r${toString manifest.package.packageRevision}";
  licenseMap = {
    "MIT" = lib.licenses.mit;
    "Apache-2.0" = lib.licenses.asl20;
    "SEE LICENSE IN README.md" = lib.licenses.unfree;
  };
  resolvedLicense =
    if builtins.hasAttr manifest.meta.licenseSpdx licenseMap
    then licenseMap.${manifest.meta.licenseSpdx}
    else lib.licenses.unfree;

  aliasOutputs = manifest.binary.aliases or [ ];
  aliasOutputLinks = lib.concatMapStrings (
    alias:
    ''
      mkdir -p "${"$" + alias}/bin"
      cat > "${"$" + alias}/bin/${alias}" <<EOF
#!${lib.getExe bash}
exec "$out/bin/${manifest.binary.name}" "\$@"
EOF
      chmod +x "${"$" + alias}/bin/${alias}"
    ''
  ) aliasOutputs;

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../package.json
      ../bun.lock
      ../patches/warren
    ];
  };

  bunDeps = bun2nix.fetchBunDeps {
    bunNix = ../bun.nix;
  };

  baseCli = bun2nix.mkDerivation {
    pname = manifest.binary.name;
    version = packageVersion;
    inherit src bunDeps;
    module = "node_modules/${manifest.package.npmName}/${manifest.binary.entrypoint}";
    bunCompileToBytecode = false;
    nativeBuildInputs = [ installShellFiles ];
    meta = with lib; {
      description = manifest.meta.description;
      homepage = manifest.meta.homepage;
      license = resolvedLicense;
      mainProgram = manifest.binary.name;
      platforms = platforms.linux ++ platforms.darwin;
    };
  };

  cli = symlinkJoin {
    pname = manifest.binary.name;
    version = packageVersion;
    name = "${manifest.binary.name}-${packageVersion}";
    outputs = [ "out" ] ++ aliasOutputs;
    paths = [ baseCli ];
    postBuild = ''
      ${aliasOutputLinks}
    '';
    meta = baseCli.meta;
  };

  # Warren server package built via bun2nix.hook to populate node_modules
  server = stdenv.mkDerivation {
    pname = "warren-server";
    version = packageVersion;
    inherit src bunDeps;

    nativeBuildInputs = [
      bun2nix.hook
      makeWrapper
    ];

    dontUseBunBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/warren $out/bin
      cp -R patches/warren/src/. node_modules/${manifest.package.npmName}/src/
      cp -r node_modules $out/lib/warren/

      makeWrapper ${bun}/bin/bun $out/bin/warren-server \
        --prefix PATH : ${lib.makeBinPath [ bun git docker-client cacert ]} \
        --set-default SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt" \
        --add-flags "run" \
        --add-flags "$out/lib/warren/node_modules/@os-eco/warren-cli/src/supervisor/main.ts" \
        --chdir "$out/lib/warren/node_modules/@os-eco/warren-cli"

      makeWrapper ${bun}/bin/bun $out/bin/warren-daemon \
        --prefix PATH : ${lib.makeBinPath [ bun git docker-client cacert ]} \
        --set-default SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt" \
        --add-flags "run" \
        --add-flags "$out/lib/warren/node_modules/@os-eco/warren-cli/src/server/main/index.ts" \
        --chdir "$out/lib/warren/node_modules/@os-eco/warren-cli"

      runHook postInstall
    '';

    meta = with lib; {
      description = "Warren control plane daemon and supervisor";
      homepage = manifest.meta.homepage;
      license = resolvedLicense;
      mainProgram = "warren-server";
      platforms = platforms.linux ++ platforms.darwin;
    };
  };
in
{
  inherit cli server;
}
