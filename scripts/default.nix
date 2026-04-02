# scripts/default.nix
{
  pkgs,
  system,
  inputs,
}:
let
  microvmPkg = inputs.microvm.packages.${system}.microvm;
  mvExe = pkgs.lib.getExe microvmPkg;
  sopsExe = pkgs.lib.getExe pkgs.sops;
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

    AGE_KEY_DIR="/var/lib/microvms/$NAME/age-key"
    AGE_KEY_FILE="$AGE_KEY_DIR/keys.txt"

    if [ ! -f "$AGE_KEY_FILE" ]; then
      echo "Extracting age key for $NAME..."
      sudo mkdir -p "$AGE_KEY_DIR"
      ${sopsExe} -d --extract '["age_key_file"]' "$FLAKE_ROOT/secrets.enc.yaml" | \
        sudo tee "$AGE_KEY_FILE" > /dev/null
      sudo chmod 600 "$AGE_KEY_FILE"
    else
      echo "Age key already exists, skipping..."
    fi
  '';

  vm-update = mkscript "vm-update" ''
    echo "Updating VM: $NAME"
    if systemctl is-active --quiet microvm@$NAME.service; then
       echo "$NAME is running, restarting after update..."
       sudo ${mvExe} -uR "$NAME"
    else
      echo "$NAME is not running, updating only..."
      sudo ${mvExe} -u "$NAME"
    fi
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
