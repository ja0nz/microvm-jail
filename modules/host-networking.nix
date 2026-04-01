/*
  #+TITLE: MicroVM host configuration
  THIS SHOULD BE PART OF YOUR HOST CONFIGURATION

  * Guest VM config
  microvm.interfaces = [{
    type = "tap";
    id = "mvm-tap1"; <-- tapPrefix!
    mac = "02:00:00:00:00:01";
  }];
*/
{ ... }:

let
  bridge = "microbr";
  gateway = "192.168.83.1";
  tapPrefix = "mvm-";
in
{
  # Create the Virtual Bridge Device
  # Defines a software-based network bridge named 'microbr'.
  # This acts as a virtual switch to connect multiple VMs together.
  systemd.network.netdevs."20-${bridge}".netdevConfig = {
    Kind = "bridge";
    Name = bridge;
  };

  # Configure the Bridge IP & Gateway
  # Assigns the host IP ${gateway} to the bridge, acting as the gateway.
  # 'ConfigureWithoutCarrier' ensures the bridge stays active even when no VMs are running.
  systemd.network.networks."20-${bridge}" = {
    matchConfig.Name = bridge;
    addresses = [ { Address = "${gateway}/24"; } ];
    networkConfig = {
      ConfigureWithoutCarrier = true;
      DHCPServer = true;
    };
  };
  networking.firewall.interfaces."${bridge}".allowedUDPPorts = [ 67 ];

  # Attach VM Interfaces to the Bridge
  # Automatically detects any interface starting with '${tapPrefix}*' (TAP devices)
  # and "plugs" them into the 'microbr' virtual switch.
  systemd.network.networks."21-microvm-tap" = {
    matchConfig.Name = "${tapPrefix}*"; # <-- here
    networkConfig.Bridge = bridge;
  };

  # Enable NAT (Internet Access)
  # Routes traffic from the internal 'microbr' network to the internet
  # Check 'networkctl status microbr' for status
  networking.nat = {
    enable = true;
    internalInterfaces = [ bridge ];
  };
}
