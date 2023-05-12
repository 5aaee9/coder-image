{ pkgs, nixpkgs, ... }:

with pkgs.dockerTools;
let
  securityWrapper = pkgs.callPackage "${nixpkgs}/nixos/modules/security/wrappers/wrapper.nix" {
    parentWrapperDir = "/run/wrappers";
  };

  user = "coder";
  mkSetuidProgram = { program , source , ... }:
    ''
      mkdir -p /run/wrappers/bin/
      cp ${securityWrapper}/bin/security-wrapper "/run/wrappers/bin/${program}"
      echo -n "${source}" > "/run/wrappers/bin/${program}.real"

      # Prevent races
      chmod 0000 "/run/wrappers/bin/${program}"
      chown root:root "/run/wrappers/bin/${program}"

      chmod "u+s,g+-s,u+rx,g+x,o+x" "/run/wrappers/bin/${program}"
    '';


  groups = {
    gid = 30000;

  };

  extraRootfsFiles = with pkgs; [
    # sudo pam
    (
      writeTextDir "etc/pam.d/sudo" ''
        account sufficient pam_unix.so
        auth sufficient pam_rootok.so
        password requisite pam_unix.so nullok sha512
        session required pam_unix.so
      ''
    )

    (
      writeTextDir "etc/nix/nix.conf" ''
        allowed-users = *
        trusted-users = root coder
        experimental-features = nix-command flakes
        sandbox = true
        sandbox-fallback = false
        substituters = https://attic.indexyz.me/indexyz https://indexyz.cachix.org https://cache.nixos.org/
        system-features = nixos-test benchmark big-parallel kvm
        trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= indexyz:XxexOMK+bHXR2slT4A9wnJg00EZFXCUYqlUhlEEGQEc= indexyz.cachix.org-1:biBEnuZ4vTSsVMr8anZls+Lukq8w4zTHAK8/p+fdaJQ=
      ''
    )

    (
      writeTextDir "etc/login.defs" ''
        DEFAULT_HOME yes
      ''
    )

    (
      writeTextDir "etc/bash.bashrc" ''
        source /share/nix-direnv/direnvrc
      ''
    )

    (
      writeTextDir "etc/sudoers.d/nopasswd" ''
        ${user} ALL=(ALL) NOPASSWD:ALL
      ''
    )
  ];
  baseRaw = buildImage {
    name = "base-raw";
    tag = "latest";

    runAsRoot = (mkSetuidProgram {
      program = "sudo";
      source = "/bin/sudo";
    }) + ''
      mkdir -p /home/coder
      chown -R coder:coder /home/coder
      mkdir /tmp
      chmod -R 777 /tmp
      cp /etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt
      chmod -R 777 /etc/ssl/certs/
    '';

    copyToRoot = pkgs.buildEnv {
      name = "image-root";
      pathsToLink = [ "/bin" "/etc" "/run/wrappers" "/share/nix-direnv" ];
      paths = with pkgs; [
        bashInteractive
        coreutils
        sudo
        linux-pam
        curl
        wget
        git
        direnv
        nix-direnv
        fish
        go
        ncurses
        less
        cacert
        nix
        gnutar
        gzip
        gnugrep
        which
        findutils
        procps
        file
        binutils

        glibc.out
        inotify-tools
        patchelf
        gnused

        # IDEs support
        code-server
        # Jetbrains fix
        (pkgs.callPackage ./base/jetbrains.nix { })

        nixpkgs
      ] ++ extraRootfsFiles ++ pkgs.callPackage ./base/user.nix {};
      #//nonRootShadowSetup { uid = 1000; user = "coder"; };
    };

    config = {
      Env = [
        "PATH=/run/wrappers/bin:/bin"
        "NIX_PATH=nixpkgs=${nixpkgs}"
      ];
    };
  };
in
# add new layer, fix ApplyLayer duplicates of file paths not supported
buildImage {
  name = "base";
  tag = "latest";
  fromImage = baseRaw;

  extraCommands = ''
    # Create nix chroot path
    mkdir -p nix/var/nix
  '';
}
