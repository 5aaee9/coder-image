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
    echo "patching fs notifier $1"
    interpreter=$(echo ${pkgs.glibc.out}/lib/ld-linux*.so.2)
    fs_notifier=$1;

    target_size=$(get_file_size $fs_notifier)
    patchelf --set-interpreter "$interpreter" $fs_notifier
    munge_size_hack $fs_notifier $target_size
  }

  find "$bin_dir" -mindepth 5 -maxdepth 5 -name launcher.sh -exec sed -i -e 's#LD_LINUX=/lib64/ld-linux-x86-64.so.2#LD_LINUX=/nix/store/xnk2z26fqy86xahiz3q797dzqx96sidk-glibc-2.37-8/lib/ld-linux-x86-64.so.2#g' {} \;
  for file in $(find "$bin_dir" -mindepth 3 -maxdepth 3 -name fsnotifier); do
    patch_fs_notifier "$file"
  done
  for file in $(find "$bin_dir" -mindepth 3 -maxdepth 3 -name fsnotifier64); do
    patch_fs_notifier "$file"
  done

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
