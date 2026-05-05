## Missing commands

If a command is not found or not installed, resolve it with these steps:

1. Find the package: `, --print-packages <cmd>` — prints the nixpkgs attribute(s) that provide the binary, no TTY needed.
2. Run via nix shell: `nix shell nixpkgs#<pkg> --command <original command>`

Example — `cowsay` not found:
```bash
, --print-packages cowsay        # prints e.g. "cowsay.out"
nix shell nixpkgs#cowsay --command cowsay "hello world"
```

Never use bare `, <cmd>` — it opens an interactive picker which fails without a TTY.
