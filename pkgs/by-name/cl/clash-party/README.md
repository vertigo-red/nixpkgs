# Packaging notes

Clash Party's GUI and native system-proxy binding are built from source.
Stable Mihomo, the separately packaged development and Smart cores,
Sub-Store, its frontend and geodata come from nixpkgs. The application and
core self-updaters are disabled; update those packages through Nix.

The NixOS module keeps the GUI unprivileged. With `tunMode` enabled, it
creates capability wrappers for the selected package's three core binaries.
Users outside the configured group can use ordinary unprivileged proxy mode.
For example:

```nix
programs.clash-party = {
  enable = true;
  tunMode = true;
  autoStart = true;
};
users.users.alice.extraGroups = [ "clash-party" ];
```

A new group membership requires a new login session. Profiles, geodata
and Sub-Store data are stored in the writable user configuration directory
under `mihomo-party`, independently of the immutable package resources.

## Validation

`nix-build -A clash-party` runs upstream unit tests. The package's
`passthru.tests.nixos` checks group access, capabilities and a real TUN
device for each bundled core without running the cores as root.
`mihomo-alpha` and `mihomo-smart` also run upstream offline unit tests;
their NixOS tests exercise authenticated HTTP/SOCKS proxy traffic.
