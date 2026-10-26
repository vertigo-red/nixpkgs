# Clash Party {#module-programs-clash-party}

Clash Party is a desktop client for managing Mihomo profiles, proxies and
TUN connections. The package includes stable, development and Smart cores
built from source, together with Sub-Store and geodata from Nixpkgs.

Enable the application with:

```nix
{
  programs.clash-party.enable = true;
}
```

Set {option}`programs.clash-party.autoStart` to start the application at login.
Profiles and other mutable data live in the user's configuration directory
under `mihomo-party`. Application and core self-updates are disabled; update
the packages through NixOS instead.

## TUN mode {#module-programs-clash-party-tun}

TUN mode needs additional network capabilities. The module grants these to
wrappers for the three packaged core executables. The GUI continues to run
as the logged-in user without those capabilities.

```nix
{
  programs.clash-party = {
    enable = true;
    tunMode = true;
  };
  users.users.alice.extraGroups = [ "clash-party" ];
}
```

Replace `alice` with your user name and log in again after changing group
membership. Only members of {option}`programs.clash-party.group` can execute
the capability wrappers. Other users can use ordinary proxy mode.

Enabling {option}`programs.clash-party.tunMode` loads the TUN kernel module
and defaults reverse path filtering to `loose`. Strict reverse path filtering
is incompatible with this mode. Configure the desired TUN routing and DNS
settings in the application's profile.
