{ pkgs, ... }:

with pkgs;
let
  groups = [
    {
      name = "root";
      gid = 0;
    }
    {
      name = "coder";
      gid = 1000;
    }
    {
      name = "nixbld";
      gid = 30000;
    }
  ];

  users = [
    {
      gid = 0;
      uid = 0;
      name = "root";
      home = "/root";
      shell = "/bin/fish";
      description = "root";
    }
    {
      gid = 1000;
      uid = 1000;
      name = "coder";
      home = "/home/coder";
      shell = "/bin/fish";
      description = "coder";
    }
  ] ++ (map (n: {
    uid = 30000 + n;
    gid = 30000;
    name = "nixbld${toString n}";
    home = "/var/empty";
    shell = "/bin/false";
    groups = [ "nixbld" ];
    description = "Nix build user ${toString n}";
  }) (pkgs.lib.lists.range 1 32));


 userToPasswd = (
    u: "${u.name}:x:${toString u.uid}:${toString u.gid}:${u.description}:${u.home}:${u.shell}"
  );

  passwdContents = (
    lib.concatStringsSep "\n"
      (map userToPasswd users)
  );

  shadowContents = (lib.concatStringsSep "\n" (
    map (user: "${user.name}:!x:::::::") users
  ));

  groupContents = (lib.concatStringsSep "\n" (
    map (g: "${g.name}:x:${toString g.gid}:") groups
  ));

  groupShadowContents = (lib.concatStringsSep "\n" (
    map (g: "${g.name}:x::") groups
  ));
in
[
  (writeTextDir "etc/passwd" passwdContents)
  (writeTextDir "etc/shadow" shadowContents)
  (writeTextDir "etc/group" groupContents)
  (writeTextDir "etc/gshadow" groupShadowContents)
]
