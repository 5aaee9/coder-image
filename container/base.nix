{ pkgs, nixpkgs, ... }:

with pkgs.dockerTools;
let
  securityWrapper = pkgs.callPackage "${nixpkgs}/nixos/modules/security/wrappers/wrapper.nix" {
    parentWrapperDir = "/run/wrappers";
  };

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

  nonRootShadowSetup = { user, uid, gid ? uid }: with pkgs; [
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
      writeTextDir "etc/shadow" ''
        root:!x:::::::
        ${user}:!:::::::
      ''
    )
    (
      writeTextDir "etc/passwd" ''
        root:x:0:0:System administrator:/root:/bin/fish
        ${user}:x:${toString uid}:${toString gid}::/home/${user}:/bin/fish
      ''
    )
    (
      writeTextDir "etc/group" ''
        root:x:0:
        ${user}:x:${toString gid}:
      ''
    )
    (
      writeTextDir "etc/gshadow" ''
        root:x::
        ${user}:x::
      ''
    )
    (
      writeTextDir "etc/sudoers.d/nopasswd" ''
        ${user} ALL=(ALL) NOPASSWD:ALL
      ''
    )
  ];
in
buildImage {
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
      code-server
      cacert
    ] ++ nonRootShadowSetup { uid = 1000; user = "coder"; };
  };

  config = {
    Env = [
      "PATH=/run/wrappers/bin:/bin"
    ];
  };
}
