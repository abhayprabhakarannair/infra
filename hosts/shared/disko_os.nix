{lib, ...}: {
  disko.devices.disk.main = {
    type = "disk";
    device = lib.mkDefault "/dev/vda";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            extraArgs = ["-n" "BOOT"];
            mountpoint = "/boot";
            mountOptions = ["fmask=0022" "dmask=0022"];
          };
        };
        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "enc";
            extraOpenArgs = ["--allow-discards"];
            content = {
              type = "btrfs";
              extraArgs = ["-f" "-L" "NixOS"];
              subvolumes = {
                "@" = {
                  mountpoint = "/";
                  mountOptions = ["compress=zstd" "noatime"];
                };
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = ["compress=zstd" "noatime"];
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = ["compress=zstd" "noatime"];
                };
                "@swap" = {
                  mountpoint = "/swap";
                  mountOptions = ["noatime"];
                  swap.swapfile.size = "32G";
                };
              };
            };
          };
        };
      };
    };
  };
}
