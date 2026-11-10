# Clash Party {#module-programs-clash-party}

*Source:* {file}`modules/programs/clash-party.nix`

*Upstream documentation:* <https://github.com/mihomo-party-org/clash-party>

Clash Party is a graphical proxy client based on Mihomo. To install it, enable
[programs.clash-party.enable](#opt-programs.clash-party.enable):

```nix
{
  programs.clash-party.enable = true;
}
```

Start Clash Party from the desktop application menu or with the `clash-party`
command. The graphical application runs as the current user.

## Autostart {#module-programs-clash-party-autostart}

Enable [programs.clash-party.autoStart](#opt-programs.clash-party.autoStart) to
start the application automatically when logging into a desktop session:

```nix
{
  programs.clash-party = {
    enable = true;
    autoStart = true;
  };
}
```

## TUN mode {#module-programs-clash-party-tun}

Enable [programs.clash-party.tunMode](#opt-programs.clash-party.tunMode) to grant
the Mihomo core the network capabilities required for TUN mode. The module
provides a NixOS security wrapper for the core, while the graphical application
continues to run as the current user. TUN mode can then be enabled in the
application.

Access to the wrapper is restricted to
[programs.clash-party.group](#opt-programs.clash-party.group), which defaults to
`users`. For example, to restrict access to members of `wheel`:

```nix
{
  programs.clash-party = {
    enable = true;
    tunMode = true;
    group = "wheel";
  };
}
```

TUN mode sets the default of
[networking.firewall.checkReversePath](#opt-networking.firewall.checkReversePath)
to `"loose"`. If overriding this option, use `"loose"` or `false`; strict reverse
path filtering is incompatible with this module's TUN mode.

## Updates and package selection {#module-programs-clash-party-updates}

The package uses Electron, Mihomo and geodata from Nixpkgs. Application and core
updates are managed through Nix; in-application core selection and updates are
disabled.

Use [programs.clash-party.package](#opt-programs.clash-party.package) to select a
customized package. When TUN mode is enabled, the security wrapper uses the
Mihomo dependency provided by that package.
