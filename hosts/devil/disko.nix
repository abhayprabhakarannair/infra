{lib, ...}: {
  disko.devices.disk.main = {
    type = "disk";
    device = lib.mkDefault "/dev/nvme1n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {size = "1G"; type = "EF00"; content = {type = "filesystem"; format = "vfat"; mountpoint = "/boot"; mountOptions = ["umask=0077"];};};
        cryptroot = {
          size = "100%";
          content = {type = "luks"; name = "cryptroot"; settings.allowDiscards = true; content = {type = "btrfs"; extraArgs = ["-f"]; subvolumes = {
            "@nix" = {mountpoint = "/nix"; mountOptions = ["compress=zstd" "noatime"];};
            "@persistent" = {mountpoint = "/persistent"; mountOptions = ["compress=zstd" "noatime"];};
            "@swap" = {mountpoint = "/swap"; mountOptions = ["noatime"]; swap.swapfile.size = "32G";};
          };};};
        };
      };
    };
  };

  disko.devices.disk.games = {
    type = "disk";
    device = lib.mkDefault "/dev/nvme0n1";
    content = {type = "gpt"; partitions.steam_library = {size = "100%"; content = {type = "btrfs"; extraArgs = ["-f" "-L" "Games"]; subvolumes."@games" = {mountpoint = "/mnt/games"; mountOptions = ["compress=zstd" "noatime" "space_cache=v2" "nofail"];};};};};
  };
}
