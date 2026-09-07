{lib, ...}: {
  disko.devices.disk.games = {
    type = "disk";
    device = lib.mkDefault "/dev/vdb";
    content = {
      type = "gpt";
      partitions = {
        steam_library = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = ["-f" "-L" "Games"];
            subvolumes = {
              "@games" = {
                mountpoint = "/mnt/games";
                mountOptions = ["compress=zstd" "noatime" "space_cache=v2" "nofail"];
              };
            };
          };
        };
      };
    };
  };
}
