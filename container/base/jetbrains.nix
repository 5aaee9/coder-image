{ pkgs, ... }:

# https://github.com/NixOS/nixpkgs/issues/153335#issuecomment-1139366573
pkgs.writeScriptBin "fix-jetbrains-server" ''
  #!/bin/bash
  set -euo pipefail
  bin_dir=~/.cache/JetBrains/RemoteDev/dist/

  mkdir -p ~/.cache/JetBrains/RemoteDev/dist/

  get_file_size() {
    fname="$1"
    echo $(ls -l $fname | cut -d ' ' -f5)
  }
  munge_size_hack() {
    fname="$1"
    size="$2"
    strip $fname
    truncate --size=$size $fname
  }

  patch_fs_notifier() {
    interpreter=$(echo ${pkgs.glibc.out}/lib/ld-linux*.so.2)
    fs_notifier=$1;

    if [ -z "$in" ]; then
      read fs_notifier;
    fi

    target_size=$(get_file_size $fs_notifier)
    patchelf --set-interpreter "$interpreter" $fs_notifier
    munge_size_hack $fs_notifier $target_size
  }

  export -f patch_fs_notifier
  find "$bin_dir" -mindepth 5 -maxdepth 5 -name launcher.sh -exec sed -i -e 's#LD_LINUX=/lib64/ld-linux-x86-64.so.2#LD_LINUX=${pkgs.glibc.out}/lib/ld-linux-x86-64.so.2#g' {} \;
  find "$bin_dir" -mindepth 3 -maxdepth 3 -name fsnotifier -exec bash -c 'patch_fs_notifier "{}"' \;
  find "$bin_dir" -mindepth 3 -maxdepth 3 -name fsnotifier64 -exec bash -c 'patch_fs_notifier "{}"' \;

  while IFS=: read -r out event; do
    case "$out" in
      */remote-dev-server/bin)
        sed -i 's#LD_LINUX=/lib64/ld-linux-x86-64.so.2#LD_LINUX=${pkgs.glibc.out}/lib/ld-linux-x86-64.so.2#g' "$out/launcher.sh"

        if [[ "${pkgs.stdenv.hostPlatform.system}" == "x86_64-linux" && -e $out/fsnotifier64 ]]; then
          patch_fs_notifier $out/fsnotifier64
        else
          patch_fs_notifier $out/fsnotifier
        fi
      ;;
    esac
  done < <(inotifywait -r -m -q -e CREATE --include '^.*ideaIU[-[:digit:]\.]+(/plugins)?(/remote-dev-server)?(/bin)?$' --format '%w%f:%e' "$bin_dir")
''
