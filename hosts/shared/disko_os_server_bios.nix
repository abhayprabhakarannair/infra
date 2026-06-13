{ lib, config, ... }: {

  options = {
    myStorage.swapSize = lib.mkOption {
      type = lib.types.str;
      default = "4G";
      description = "The size of the Btrfs swapfile.";
    };
  };

  config = {
    disko.devices.disk.main = {
      type = "disk";
      device = lib.mkDefault "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "1M";
            type = "EF02";
          };
          root = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" "-L" "NixOS" ];
              subvolumes = {
                "@" = { mountpoint = "/"; mountOptions = [ "compress=zstd" "noatime" ]; };
                "@home" = { mountpoint = "/home"; mountOptions = [ "compress=zstd" "noatime" ]; };
                "@nix" = { mountpoint = "/nix"; mountOptions = [ "compress=zstd" "noatime" ]; };
                "@swap" = {
                  mountpoint = "/swap";
                  mountOptions = [ "noatime" ];
                  swap.swapfile.size = config.myStorage.swapSize;
                };
                "@srv" = { mountpoint = "/srv"; mountOptions = [ "compress=zstd" "noatime" ]; };
                "@var_lib_portables" = { mountpoint = "/var/lib/portables"; mountOptions = [ "compress=zstd" "noatime" ]; };
                "@var_lib_machines" = { mountpoint = "/var/lib/machines"; mountOptions = [ "compress=zstd" "noatime" ]; };
                "@var_tmp" = { mountpoint = "/var/tmp"; mountOptions = [ "compress=zstd" "noatime" ]; };
              };
            };
          };
        };
      };
    };
  };
}
