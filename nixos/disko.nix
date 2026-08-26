{
  disko,
  ...
}:

{
  imports = [ disko.nixosModules.disko ];

  disko.devices = {
    disk.vda = {
      type = "disk";
      device = "/dev/vda";

      content = {
        type = "gpt";

        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";

            content = {
              type = "filesystem";
              format = "vfat";
              extraArgs = [
                "-n"
                "BOOT"
              ];
              mountpoint = "/boot";
            };
          };

          root = {
            size = "100%";

            content = {
              type = "filesystem";
              format = "ext4";
              extraArgs = [
                "-L"
                "NIXOS"
              ];
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
