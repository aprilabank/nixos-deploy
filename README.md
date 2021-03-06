# nixos-deploy

A tool similar to `nixops` but limited to remote ssh deployment;
essentially `nixos-rebuild` on steroids.


## Features

- describe and deploy an interdependant set of NixOS machines
- supports all NixOS activation commands (dry-activate, test, switch,
  boot)
- the `build-image` command builds an image with the target
  configuration on the build host, ready to be deployed as a VM
- the `install` command makes it easy to `nixos-install` a target
  configuration on a disk, even from a non-NixOS machine
- the `diff` command uses `nix-diff` to show the differences between
  the currently running system and the one to be deployed
- supports having a separate build host for each node
- modular code structure to make creating new commands (relatively)
  easy


## Usage

```
    nixos-deploy.sh [-f hosts_file] [--fast] [--no-ssh-multiplexing] [BUILD_OPTIONS...] host action
```

## Example

```nix
let
  common_conf = { config, pkgs, lib, name, nodes, ... }: {
    # The `name` module parameter refers to the node name (here machine1 or machine2)
    deployment.targetHost = "root@${name}";
    networking.hostName = name;
  };

in
{
  machine1 = { config, pkgs, lib, name, nodes, ... }: {
    imports = [ common_conf ];

    services.nginx = {
      enable = true;
      # The `nodes` module parameter contains all the nodes' computed configurations
      virtualhosts.machine2.locations."/".proxyPass = "http://${nodes.machine2.custom.ip}";
    };
  };

  machine2 = { config, pkgs, lib, name, nodes, ... }: {
    imports = [ common_conf ];

    deployment.buildHost = "build@machine1";

    custom.ip = "10.0.0.2";

    services.radicale.enable = true;
  };
}
```

Run

```
nixos-deploy.sh -f machines.nix machine1 switch
```

to deploy the configuration to `machine1` via ssh.
