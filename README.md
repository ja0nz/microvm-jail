# MicroVM Jail for Agents and Services

This repository provides a lightweight VM jail for running agents and services with limited system access.
It uses [microvm.nix](https://github.com/microvm-nix/microvm.nix) to create and manage lightweight VMs.

## Why?

When you need to run untrusted code (e.g., AI agents, third‑party services) you want strong isolation but also want to keep overhead low.
Full VMs are heavy, containers (Docker) share the kernel and are not sufficient for true security isolation.
MicroVMs offer a middle ground: they are tiny virtual machines that boot quickly and have minimal resource overhead while still providing full kernel isolation.

Other approaches you might consider:
- **[jail.nix](https://sr.ht/~alexdavid/jail.nix/)** – uses Linux namespaces and cgroups (similar to containers).
- **[nix‑bwrapper](https://github.com/Naxdy/nix-bwrapper)** – uses Bubblewrap to sandbox Nix‑built programs.

This flake chooses microvm.nix because it gives you the strongest isolation while staying easy to manage and integrate with NixOS.

## Requirements

- NixOS with flakes enabled.
- systemd‑networkd must be enabled (the host network module adds configuration but does not enable the service). If your host uses a different network manager you may need to adapt the configuration.
- KVM support in the host CPU and kernel (for hardware acceleration).
- The hypervisor (qemu or cloud‑hypervisor) will be pulled automatically by microvm.nix.

## Quick Start

1. **Enable flakes** if you haven't already.
2. **Clone this repository** and `cd` into it.
3. **Add the host network configuration** (see below) to your host NixOS configuration.
4. **Create a secrets file** (optional, only needed if you want to use SOPS).
5. **Run `nix shell`** to enter a development shell with all management scripts.
6. **Create a VM** with `vm-create <name>`.
7. **Connect via SSH** with `ssh-connect <name>`.

## Host Network Configuration

The file `modules/_host-network.nix` must be imported into your **host** NixOS configuration.
It sets up:
- A bridge `microbr` with address `192.168.83.1/24`.
- DHCP and DNS server (dnsmasq) for the `.mvm` domain.
- IP forwarding and masquerading (NAT) so VMs can reach the internet.
- Automatic attachment of any tap interface whose name starts with `mvm-`.

If you need a different subnet or domain, you can modify the variables at the top of `modules/_host-network.nix`.

### How to import

Add the module to your host's `configuration.nix` or to a module list:

```nix
{ ... }:
{
  imports = [
    /path/to/this/repo/modules/_host-network.nix
  ];
}
```

After rebuilding your host, you should see the bridge `microbr` and the dnsmasq service running.

### Checking DNS resolution

Once a VM is running, you can verify that its hostname resolves inside the host with:

```bash
resolvectl query <vm-name>.mvm
```

It should return the VM's IP address (e.g., `192.168.83.100`). If it doesn't, check that dnsmasq is running and that the VM's tap interface is attached to the bridge.

## Managing VMs

The flake provides several convenience scripts that wrap `microvm` commands. You can run them directly with `nix run` or use the dev shell.

### Available scripts

| Command | Description |
|---------|-------------|
| `vm-list` | List all defined microvms |
| `vm-create <name>` | Create and start a new VM (also extracts the age key) |
| `vm-update <name>` | Update a VM (restarts if running) |
| `vm-start <name>` | Start a stopped VM |
| `vm-stop <name>` | Stop a running VM |
| `vm-delete <name>` | Delete a VM (stops it first) |
| `vm-log-follow <name>` | Follow the VM's journal logs |
| `ssh-connect <name>` | SSH into the VM (uses a temporary SSH key) |

### Using the dev shell

Run `nix develop` (or `nix shell`) to get a shell where all the above commands are in your PATH. The shell also prints a reminder of the available commands.

### Using `nix run` directly

You can run a script without entering the dev shell:

```bash
nix run .#vm-create -- pi-mono
```

### How `ssh-connect` works

The script `ssh-connect` embeds a static SSH private key (matching the public key in `ident.pub`) and uses it to connect to `root@<name>.mvm`. The VM's `authorized_keys` already contains that public key, so no password is required. Note that the script disables host‑key verification (`StrictHostKeyChecking=no`) for convenience; for production use you may want to adjust the SSH options.

If you want to use your own SSH key, you can modify `ident.pub` and the private key inside `scripts/ssh-connect.sh`. Similarly, if you changed the domain in `modules/_host-network.nix`, update the `DOMAIN` variable in `scripts/ssh-connect.sh`.

## Adding new VM definitions

The flake currently defines a single VM called `pi-mono`. You can add more by editing `flake.nix`:

1. Extend the `vmList` with a new entry:
   ```nix
   {
     name = "my-microvm2";
     modules = [ ./modules/extra.nix ];
   }
   ```
2. Create a corresponding module (e.g., `modules/extra.nix`) that customizes the VM (packages, services, etc.).
3. Rebuild the flake (`nix flake update` not needed) and run `vm-create my-microvm2`.

Each VM gets a unique:
- MAC address (derived deterministically from its name)
- tap interface ID (`mvm-<id>`)
- vsock CID (`3 + id`)
- persistent image (`var-<id>.img`)

These are set in `modules/base.nix`.

By default the hypervisor is `qemu`. You can change it by setting `microvm.hypervisor = "cloud-hypervisor";` in your VM‑specific module.

## Secrets with SOPS-Nix

The VMs are set up to use [sops‑nix](https://github.com/Mic92/sops-nix) for secret management.
You need to provide an encrypted `secrets.enc.yaml` file in the repository root.
An example structure:

```yaml
openrouter_api_key: &openrouter_api_key ENC[AES256_GCM,data:...,type:str]
age_key_file: &age_key_file ENC[AES256_GCM,data:...,type:str]
sops:
  ...
```

The `vm-create` script automatically extracts the `age_key_file` secret and places it inside the VM's age‑key directory, where sops‑nix can read it.

If you don't need secrets, you can remove the sops‑nix import and the secret‑mounting logic from `modules/base.nix` and `scripts/default.nix`.

## Persistence

Each VM gets a persistent disk image (`/var/lib/microvms/<name>/var-<id>.img`) that is mounted at `/persistent` inside the VM.
The [preservation](https://github.com/nix-community/preservation) module is used to preserve selected directories across rebuilds.
By default, the following directories are preserved:
- `/var/lib/systemd/timers`
- `/var/lib/nixos`
- `/var/log`

You can extend this list in your VM‑specific module via `preservation.preserveAt."/persistent".directories`.

## How it works under the hood

- The `microvm` runner creates a systemd service (`microvm@<name>.service`) that starts the VM with the appropriate hypervisor.
- The VM's root filesystem is a tmpfs populated from the Nix store (via `virtiofs`).
- A separate persistent volume is attached as a block device.
- The host bridge `microbr` provides networking; dnsmasq hands out IP addresses and resolves `.mvm` domain names.
- The host's `systemd‑networkd` attaches tap interfaces to the bridge automatically.

## Troubleshooting

### DNS doesn't resolve

Check that dnsmasq is running on the host:

```bash
systemctl status dnsmasq
```

Check that the bridge `microbr` exists and has an IP:

```bash
ip addr show microbr
```

Check that the VM's tap interface is attached:

```bash
bridge link show dev mvm-1   # replace 1 with the VM's ID
```

### SSH connection fails

Verify that the VM is running:

```bash
systemctl status microvm@<name>
```

Check the VM's logs:

```bash
vm-log-follow <name>
```

Make sure the VM's SSH service started correctly (look for `sshd` in the logs).

### VM fails to start

Look at the journal of the microvm service:

```bash
journalctl -u microvm@<name>.service -f
```

Common issues:
- The hypervisor (qemu or cloud‑hypervisor) is not installed on the host.
- The user lacks permission to create tap interfaces (the service runs as root).
- The persistent image could not be created (check disk space).

## License

MIT
