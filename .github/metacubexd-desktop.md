# MetaCubeXD desktop on NixOS

The `metacubexd-desktop-packaging` branch packages the upstream desktop app,
profile manager, local control agent and Mihomo backend. The older `metacubexd`
attribute remains a standalone web dashboard.

Pinned packaging revision: `c53af52de31691b3f9ffb81e778fb5bd4d0cb19d`.

The workflow and its scripts live only on `ci-builds`. `master` is unchanged.

## Enable the client

Save the following as an additional NixOS module, for example
`/etc/nixos/metacubexd.nix`, and import it from your existing configuration.
Use the login of an existing normal user in `user`; for NixOS-WSL this may be
`nixos` instead of `vertigo.red`.

```nix
{ pkgs, ... }:
let
  source = builtins.fetchTarball {
    url = "https://github.com/vertigo-red/nixpkgs/archive/c53af52de31691b3f9ffb81e778fb5bd4d0cb19d.tar.gz";
    sha256 = "sha256-/Z/MWnBe02zD/oOy4fH4SctNYpHXuIaeiiL5kryd0Mw=";
  };
  desktopPkgs = import source {
    system = pkgs.stdenv.hostPlatform.system;
  };
in
{
  imports = [ "${source}/nixos/modules/programs/metacubexd-desktop.nix" ];

  nix.settings = {
    extra-substituters = [ "https://nixpkgs-pr-build-test.cachix.org" ];
    extra-trusted-public-keys = [
      "nixpkgs-pr-build-test.cachix.org-1:klCTmhIyRKEbY/UZvUv6jgoTVBp2dgwS+5j7K0YUXsY="
    ];
  };

  programs.metacubexd-desktop = {
    enable = true;
    package = desktopPkgs.metacubexd-desktop;
    tunMode = true;
    user = "vertigo.red";
    autoStart = true;
  };
}
```

For the first rebuild, pass the cache settings on the command line so that Nix
can use them before the new system configuration has been activated:

```sh
sudo nixos-rebuild switch --flake /etc/nixos#nixos \
  --option extra-substituters https://nixpkgs-pr-build-test.cachix.org \
  --option extra-trusted-public-keys 'nixpkgs-pr-build-test.cachix.org-1:klCTmhIyRKEbY/UZvUv6jgoTVBp2dgwS+5j7K0YUXsY='
```

Then launch `metacubexd-desktop`, import and activate a profile, and enable TUN
in the application. Turn off TUN in Clash Verge before testing another client.

## How TUN works

`metacubexd-helper.service` runs as the configured normal user with only
`CAP_NET_ADMIN`, `CAP_NET_RAW` and `CAP_NET_BIND_SERVICE`. The Electron GUI has
no additional privileges. The helper launches only the Mihomo binary selected
by the package, and stops that process when its owning app disconnects.

The service generates a fresh 32-byte random token in
`/run/metacubexd-helper/secret`. The runtime directory is mode `0700` and the
token is mode `0600`. Tokens and subscription credentials are not embedded in
the Nix store. The GUI rereads the token when connecting after a service restart.

The module loads `tun` and defaults reverse path filtering to `"loose"`.
It does not add trusted firewall interfaces or open proxy/controller ports.
Profile settings, subscriptions and ordinary updates of subscriptions remain
managed by the application under `$XDG_CONFIG_HOME/metacubexd`.

Mihomo executable updates are managed through Nix; the in-app kernel download
feature is hidden. The source build uses Nixpkgs' packaged binary Electron 43.

## Desktop limitation

Upstream's system-proxy switch currently uses GNOME `gsettings` on Linux and
does not configure KDE's proxy settings. TUN works independently of the desktop
environment. System-proxy support for KDE is a separate upstream feature.

## Checks and troubleshooting

The CI workflow builds with Nix sandboxing, runs the upstream desktop/agent/editor
unit tests, opens the actual Electron UI and checks its preload bridge and local
agent/Mihomo APIs, then runs a NixOS VM test with a real TUN device.

[Verified successful run](https://github.com/vertigo-red/nixpkgs/actions/runs/39560253447):
724 unit tests passed; one Windows-specific test was skipped on Linux. The GUI
smoke test and NixOS VM test both passed. Published output:
`/nix/store/iacxz7g7gbhlysx3kmmi9nk4lx23b32m-metacubexd-desktop-1.273.1`.

The VM test also checks incorrect tokens, attempts to run an unapproved binary,
access by another user, HTTP/SOCKS proxying, disconnection cleanup and service
restart. The CI build target is `x86_64-linux`; `aarch64-linux` is declared by the
recipe but has not been tested by this workflow. WSL and the user's own proxy
subscription require a separate manual check.

```sh
systemctl status metacubexd-helper.service
journalctl -b -u metacubexd-helper.service
```

Before any new upload, CI pins the existing Clash Verge Rev 2.5.8 store path
under `clash-verge-rev-2.5.8`. The verified desktop result is pinned separately as
`metacubexd-desktop-1.273.1` in the same `nixpkgs-pr-build-test` cache.
