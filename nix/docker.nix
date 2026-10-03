{
  lib,
  dockerTools,
  server,
  git,
  sd,
  cacert,
  tzdata,
  docker-client,
}:

let
  user = "warren";
  uid = "1000";
  gid = "1000";

  # Minimal /etc/passwd and /etc/group for rootless 1000:1000 user
  etcUsers = dockerTools.fakeNss;
in
dockerTools.buildLayeredImage {
  name = "warren";
  tag = server.version;

  contents = [
    server
    git
    sd
    docker-client
    cacert
    tzdata
    etcUsers
  ];

  config = {
    User = "${uid}:${gid}";
    WorkingDir = "/data";
    Entrypoint = [ "${server}/bin/warren-server" ];
    ExposedPorts = {
      "8080/tcp" = { };
      "8081/tcp" = { };
    };
    Env = [
      "HOME=/data"
      "WARREN_DATA_DIR=/data"
      "SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
    Volumes = {
      "/data" = { };
    };
  };

  # Set up /data directory owned by 1000:1000 with 0700 permissions
  fakeRootCommands = ''
    mkdir -p ./data ./tmp
    chown -R ${uid}:${gid} ./data ./tmp
    chmod 700 ./data
    chmod 1777 ./tmp
  '';
}
