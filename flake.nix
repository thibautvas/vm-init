{
  description = "vm-init";

  inputs = {
    # build nixos vm with nixpkgs rev that nix-config follows
    # other distros don't make much use of nixpkgs, should be fine
    nix-config.url = "github:thibautvas/nix-config";
    nixpkgs.follows = "nix-config/nixpkgs";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-config,
      disko,
    }:

    let
      inherit (nixpkgs) lib;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      sources = lib.importJSON ./sources.json;

      mkVm =
        {
          name,
          osinfo,
          network ? "network=default",
          memory ? 2048,
          vcpus ? 2,
          disks ? [ "size=20" ],
          extraFlags ? [ ],
        }:
        let
          flags = [
            "--connect qemu:///system"
            "--boot uefi"
            "--network ${network}"
            "--memory ${toString memory}"
            "--vcpus ${toString vcpus}"
            "--osinfo ${osinfo}"
            "--name ${name}"
            "--noautoconsole"
          ]
          ++ map (disk: "--disk ${disk}") disks
          ++ extraFlags;
        in
        pkgs.writeShellApplication {
          name = "vm-${name}";
          runtimeInputs = [
            pkgs.libvirt
            pkgs.virt-manager
          ];
          text = ''
            virt-install \
              ${lib.concatStringsSep " \\\n  " flags}
          '';
          passthru.vmName = name;
        };

      # debian: netboot installer driven by a preseed injected into the initrd
      debian =
        let
          netbootTree = sources.debian.url;
          preseedDir = ./debian;
        in
        mkVm {
          name = "debian";
          osinfo = sources.debian.osinfo;
          extraFlags = [
            "--location ${netbootTree}"
            "--initrd-inject ${preseedDir}/preseed.cfg"
            "--extra-args 'auto=true priority=critical hostname=debian domain= preseed/file=/preseed.cfg'"
          ];
        };

      # archlinux: boot the iso with a cloud-init seed that runs archinstall
      # the next boot comes from the installed disk
      archlinux =
        let
          iso = pkgs.fetchurl {
            inherit (sources.archlinux) url sha256;
          };

          cloudCfg = pkgs.writeText "cloud-config" (
            "#cloud-config\n"
            + builtins.toJSON {
              write_files = [
                {
                  path = "/root/user_configuration.json";
                  permissions = "0600";
                  content = builtins.readFile ./archlinux/user_configuration.json;
                }
              ];
              runcmd = [ "archinstall --config /root/user_configuration.json --silent" ];
              power_state = {
                mode = "poweroff";
                condition = true;
              };
            }
          );

          seed =
            pkgs.runCommand "arch-seed"
              {
                nativeBuildInputs = [ pkgs.cdrkit ];
              }
              ''
                mkdir -p seed $out
                cp ${cloudCfg} seed/user-data
                touch seed/meta-data
                genisoimage -quiet -output $out/seed.iso -volid CIDATA -joliet -rock seed
              '';
        in
        mkVm {
          name = "archlinux";
          osinfo = sources.archlinux.osinfo;
          disks = [
            "size=20,boot.order=1"
            "path=${iso},device=cdrom,readonly=on,boot.order=2"
            "path=${seed}/seed.iso,device=cdrom,readonly=on"
          ];
          extraFlags = [ "--import" ];
        };

      # alpinelinux: boot the iso with an apkovl that appends an autoinstall service to inittab
      alpinelinux =
        let
          iso = pkgs.fetchurl {
            inherit (sources.alpinelinux) url sha256;
          };

          inittab = pkgs.writeText "inittab" ''
            # /etc/inittab
            ::sysinit:/sbin/openrc sysinit
            ::sysinit:/sbin/openrc boot
            ::wait:/sbin/openrc default
            ::wait:/sbin/autoinstall
          '';

          # runs once on the live system, then removes itself before installing
          autoinstall = pkgs.writeScript "autoinstall" ''
            #!/bin/sh
            cp /etc/setup-alpine.conf /tmp/answers
            sed -i '/autoinstall/d' /etc/inittab
            rm -f /sbin/autoinstall /etc/setup-alpine.conf
            ERASE_DISKS=$(. /tmp/answers >/dev/null 2>&1; echo "''${DISKOPTS##* }")
            export ERASE_DISKS
            setup-alpine -e -f /tmp/answers 2>&1 | tee /dev/tty0
            reboot
          '';

          apkovl = pkgs.runCommand "alpine-apkovl" { } ''
            mkdir -p ovl/etc ovl/sbin $out
            touch ovl/etc/.default_boot_services
            cp ${inittab} ovl/etc/inittab
            cp ${./alpinelinux/setup-alpine.conf} ovl/etc/setup-alpine.conf
            cp ${autoinstall} ovl/sbin/autoinstall
            tar -C ovl -czf $out/alpine.apkovl.tar.gz \
              --owner=0 --group=0 --numeric-owner --sort=name --mtime=@1 .
          '';
        in
        mkVm {
          name = "alpinelinux";
          osinfo = sources.alpinelinux.osinfo;
          extraFlags = [
            "--location ${iso},kernel=/boot/vmlinuz-virt,initrd=/boot/initramfs-virt"
            "--initrd-inject ${apkovl}/alpine.apkovl.tar.gz"
            ''--extra-args "apkovl=/alpine.apkovl.tar.gz modules=loop,squashfs,sd-mod,usb-storage console=tty0 console=ttyS0"''
          ];
        };

      # nixos: boot minimal iso and install with partitioning over ssh
      nixos =
        let
          # authorized keys for easier handling of the ssh deploy
          authKey = user: {
            users.users.${user}.openssh.authorizedKeys.keys = [ (builtins.readFile ./id_rsa.pub) ];
          };

          # minimal installer, authorized for root
          nixosIso =
            (lib.nixosSystem {
              inherit system;
              modules = [
                (
                  { modulesPath, ... }:
                  {
                    imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];
                    services.openssh.enable = true;
                  }
                )
                (authKey "root")
              ];
            }).config.system.build.isoImage;

          nixosInstall = mkVm {
            name = "nixos";
            osinfo = "nixos-unknown";
            disks = [
              "size=20,boot.order=1"
              "path=${nixosIso}/iso/${nixosIso.isoName},device=cdrom,readonly=on,boot.order=2"
            ];
            extraFlags = [ "--import" ];
          };

          # guest config with disko partitions
          guest = nix-config.nixosConfigurations.guest.extendModules {
            modules = [
              (import ./nixos/disko.nix {
                inherit disko;
              })
              (authKey "thibautvas")
            ];
          };

          inherit (guest.config.system.build) diskoScript toplevel;

          # wrap ssh with loose checks to avoid noise
          sshWrapper = pkgs.writeShellScriptBin "ssh" ''
            exec ${pkgs.openssh}/bin/ssh \
              -F /dev/null \
              -o StrictHostKeyChecking=no \
              -o UserKnownHostsFile=/dev/null \
              -o LogLevel=ERROR \
              "$@"
          '';

        in
        # nixos: final stiching
        pkgs.writeShellApplication {
          name = "vm-nixos-full";
          runtimeInputs = [
            sshWrapper
            nixosInstall
          ];
          text = ''
            vm-nixos

            until ip=$(virsh --connect qemu:///system --quiet domifaddr ${nixosInstall.vmName} |
              awk '/ipv4/{print $4}' | cut -d/ -f1) && [ -n "$ip" ]; do
              sleep 1
            done
            target="root@$ip"

            until ssh "$target" true 2>/dev/null; do
              sleep 1
            done

            nix copy --no-check-sigs --to "ssh://$target" ${diskoScript}
            ssh "$target" ${diskoScript}

            nix copy --no-check-sigs --to "ssh://$target?remote-store=local%3Froot=/mnt" ${toplevel}
            ssh "$target" \
              nixos-install --no-root-passwd --no-channel-copy --system ${toplevel}

            ssh "$target" poweroff || true
          '';
        };

    in
    {
      packages.${system} = {
        default = nixos;
        inherit
          alpinelinux
          archlinux
          debian
          nixos
          ;
      };
    };
}
