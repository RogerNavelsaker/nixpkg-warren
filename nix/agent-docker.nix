{
  lib,
  buildEnv,
  dockerTools,
  bashInteractive,
  coreutils,
  curl,
  findutils,
  gnutar,
  gnugrep,
  gzip,
  gitMinimal,
  gh,
  jq,
  cacert,
  tzdata,
  bun,
  python3,
  python3Packages,
  uv,
  nodejs_22,
  gnused,
  gawk,
  which,
  diffutils,
  glibc,
  binutils,
  ripgrep,
  piPackage,
  seedsPackage,
  seedsAliasPackage,
  mulchPackage,
  mulchAliasPackage,
  canopyPackage,
  canopyAliasPackage,
  saplingPackage,
  saplingAliasPackage,
  plotPackage,
  plotAliasPackage,
  terrariumPackage,
  trellisPackage,
}:

let
  user = "agent";
  uid = "1000";
  gid = "1000";

  agentPackages = [
    bashInteractive
    coreutils
    curl
    findutils
    gnutar
    gnugrep
    gzip
    gitMinimal
    gh
    jq
    cacert
    tzdata
    bun
    python3
    python3Packages.pip
    uv
    nodejs_22
    gnused
    gawk
    which
    diffutils
    binutils
    ripgrep
    piPackage
    seedsPackage
    seedsAliasPackage
    mulchPackage
    mulchAliasPackage
    canopyPackage
    canopyAliasPackage
    saplingPackage
    saplingAliasPackage
    plotPackage
    plotAliasPackage
    terrariumPackage
    trellisPackage
  ];

  runtime = buildEnv {
    name = "warren-agent-env";
    paths = agentPackages;
    pathsToLink = [ "/bin" "/lib" "/share" ];
  };

  etcUsers = dockerTools.fakeNss;
in
dockerTools.buildLayeredImage {
  name = "warren-agent";
  tag = "latest";

  contents = [
    runtime
    glibc.bin
    cacert
    tzdata
    etcUsers
  ];

  config = {
    User = "${uid}:${gid}";
    WorkingDir = "/workspace";
    Entrypoint = [ "${piPackage}/bin/pi" ];
    Env = [
      "HOME=/workspace"
      "PI_CODING_AGENT_HOME=/workspace/.pi"
      "PATH=/bin:/usr/bin:${runtime}/bin:${glibc.bin}/bin"
      "SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
    Volumes = {
      "/workspace" = { };
    };
  };

  extraCommands = ''
    mkdir -p ./usr/bin ./workspace ./tmp ./home/agent
    ln -sf ${coreutils}/bin/env ./usr/bin/env
  '';

  fakeRootCommands = ''
    chown -R ${uid}:${gid} ./workspace ./home/agent ./tmp
    chmod 755 ./workspace ./home/agent
    chmod 1777 ./tmp
  '';
}
