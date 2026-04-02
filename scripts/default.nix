# scripts/default.nix
{ pkgs, microvmPkg }:
let
  mvExe = pkgs.lib.getExe microvmPkg;
  sysCtl = pkgs.lib.getExe' pkgs.systemd "systemctl";
  jCtl = pkgs.lib.getExe' pkgs.systemd "journalctl";
  script = pkgs.writeShellScriptBin;

  mkscript =
    name: body:
    script name ''
      set -e
      NAME="$1"
      if [ -z "$NAME" ]; then
        echo "Usage: ${name} <name>"
        exit 1
      fi
      ${body}
    '';
in
{
  ssh-connect = script "ssh-connect" (builtins.readFile ./ssh-connect.sh);

  vm-list = script "vm-list" ''
    ${mvExe} -l
  '';

  vm-create = mkscript "vm-create" ''
    echo "Creating VM: $NAME"
    sudo ${mvExe} -f "git+file://$FLAKE_ROOT" -c "$NAME"
  '';

  vm-update = mkscript "vm-update" ''
    echo "Updating VM: $NAME"
    sudo ${mvExe} -u "$NAME"
  '';

  vm-start = mkscript "vm-start" ''
    echo "Starting VM: $NAME"
    sudo ${sysCtl} start microvm@$NAME.service
  '';

  vm-stop = mkscript "vm-stop" ''
    echo "Stopping VM: $NAME"
    sudo ${sysCtl} stop microvm@$NAME.service
  '';

  vm-delete = mkscript "vm-delete" ''
    vm-stop $NAME
    echo "Deleting VM: $NAME"
    sudo rm -rf /var/lib/microvms/$NAME
  '';

  vm-log-follow = mkscript "vm-log-follow" ''
    ${jCtl} -u microvm@$NAME.service -f
  '';
}
