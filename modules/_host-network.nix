/*
  #+TITLE: MicroVM host configuration
  THIS SHOULD BE PART OF YOUR HOST CONFIGURATION
  * Guest VM config
  microvm.interfaces = [{
    type = "tap";
    id = "mvm-tap1"; <-- tapPrefix (mvm-)!
    mac = "02:00:00:00:00:01";
  }];
*/
{ ... }:
let
  bridge = "microbr";
  gateway = "192.168.83.1";
  # tap interface prefix (mvm-*)
  tapPrefix = "mvm-";
  # local DNS domain (<vm-name>.mvm)
  tapDomain = "mvm";
in
{
  # Create the Virtual Bridge Device
  systemd.network.netdevs."20-${bridge}".netdevConfig = {
    Kind = "bridge";
    Name = bridge;
  };

  # Enable IP Forwarding (Required for NAT)
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };

  # Configure the Bridge IP & Gateway
  systemd.network.networks."20-${bridge}" = {
    matchConfig.Name = bridge;
    addresses = [ { Address = "${gateway}/24"; } ];
    networkConfig = {
      ConfigureWithoutCarrier = true;
      DNSOverTLS = "no";
      IPMasquerade = "both";
    };
    dns = [ gateway ];
    domains = [ "~${tapDomain}" ];
  };

  # Attach VM Interfaces to the Bridge
  systemd.network.networks."21-microvm-tap" = {
    matchConfig.Name = "${tapPrefix}*";
    networkConfig.Bridge = bridge;
  };

  # dnsmasq: DHCP + DNS for VMs
  services.dnsmasq = {
    enable = true;
    settings = {
      interface = bridge;
      bind-interfaces = true;
      listen-address = gateway;
      dhcp-range = [ "192.168.83.100,192.168.83.200,24h" ];
      dhcp-option = [
        "option:router,${gateway}"
        "option:dns-server,${gateway}"
      ];
      local = "/${tapDomain}/";
      domain = "${tapDomain}";
      expand-hosts = true;
    };
  };

  # Taken from https://wiki.nixos.org/wiki/Networking#Virtualization
  networking.firewall.interfaces."${bridge}".allowedUDPPorts = [
    53
    67
  ];
}
