let
  immutable = [
    "--read-only"
    "--tmpfs=/tmp:rw,noexec,nosuid,nodev"
    "--tmpfs=/run:rw,nosuid,nodev"
  ];

  withLimits = {
    pidsLimit,
    memory,
    cpus,
  }: [
    "--pids-limit=${toString pidsLimit}"
    "--memory=${memory}"
    "--cpus=${toString cpus}"
  ];
in {
  baseline = [
    "--security-opt=no-new-privileges"
    "--cap-drop=ALL"
  ];

  inherit immutable withLimits;
  immutableWithLimits = limits: immutable ++ withLimits limits;
}
