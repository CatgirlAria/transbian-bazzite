{
  pkgs,
  ...
}:
{
  boot.initrd.systemd.services.btrfs-root-reset = {
    description = "Reset ephemeral Btrfs root";

    # LUKS has to be unlocked first.
    requires = [
      "systemd-cryptsetup@crypted.service"
    ];

    after = [
      "systemd-cryptsetup@crypted.service"
    ];

    # But reset root before systemd mounts it.
    before = [
      "sysroot.mount"
    ];

    wantedBy = [
      "initrd-root-fs.target"
    ];

    unitConfig.DefaultDependencies = false;

    serviceConfig.Type = "oneshot";

    path = [
      pkgs.btrfs-progs
      pkgs.coreutils
      pkgs.findutils
      pkgs.util-linux
    ];

    script = ''
      set -eu

      mkdir -p /btrfs_tmp

      # Mount the Btrfs top-level, NOT the root subvolume.
      mount \
        -t btrfs \
        -o subvolid=5 \
        /dev/mapper/crypted \
        /btrfs_tmp

      if [[ -e /btrfs_tmp/root ]]; then
        mkdir -p /btrfs_tmp/old_roots

        timestamp="$(
          date \
            --date="@$(stat -c %Y /btrfs_tmp/root)" \
            "+%Y-%m-%d_%H:%M:%S"
        )"

        mv \
          /btrfs_tmp/root \
          "/btrfs_tmp/old_roots/$timestamp"
      fi

      delete_subvolume_recursively() {
        local subvolume="$1"

        while IFS= read -r child; do
          [[ -z "$child" ]] && continue

          delete_subvolume_recursively "/btrfs_tmp/$child"
        done < <(
          btrfs subvolume list -o "$subvolume" |
            cut -f 9- -d ' '
        )

        btrfs subvolume delete "$subvolume"
      }

      if [[ -d /btrfs_tmp/old_roots ]]; then
        while IFS= read -r old_root; do
          delete_subvolume_recursively "$old_root"
        done < <(
          find \
            /btrfs_tmp/old_roots \
            -mindepth 1 \
            -maxdepth 1 \
            -mtime +30
        )
      fi

      btrfs subvolume create /btrfs_tmp/root

      umount /btrfs_tmp
    '';
  };
}