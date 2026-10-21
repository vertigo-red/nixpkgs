{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.metacubexd-desktop;
  userExists = cfg.user != null && builtins.hasAttr cfg.user config.users.users;
  helperUser = if userExists then config.users.users.${cfg.user} else null;
  capabilities = [
    "CAP_NET_ADMIN"
    "CAP_NET_RAW"
    "CAP_NET_BIND_SERVICE"
  ];
in
{
  options.programs.metacubexd-desktop = {
    enable = lib.mkEnableOption "MetaCubeXD desktop";

    package = lib.mkPackageOption pkgs "metacubexd-desktop" { };

    tunMode = lib.mkEnableOption ''
      the systemd helper needed for TUN mode. Enable TUN in the application
      after activating a profile. Reverse path filtering defaults to loose
    '';

    user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "alice";
      description = ''
        Normal user allowed to use the TUN helper. Required when
        {option}`programs.metacubexd-desktop.tunMode` is enabled.

        The helper runs as this user with network capabilities. Its
        authentication token and socket are accessible only to this user.
        The helper can execute only the Mihomo provided by the package.
        Kernel updates are managed through Nix.
      '';
    };

    autoStart = lib.mkEnableOption "MetaCubeXD desktop at graphical login";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ]
    ++ lib.optional cfg.autoStart (
      pkgs.makeAutostartItem {
        name = "metacubexd-desktop";
        package = cfg.package;
      }
    );

    assertions = [
      {
        assertion = cfg.tunMode -> userExists && helperUser.isNormalUser;
        message = ''
          programs.metacubexd-desktop.tunMode requires
          programs.metacubexd-desktop.user to name an existing normal user.
        '';
      }
      {
        assertion =
          cfg.tunMode
          -> !builtins.elem config.networking.firewall.checkReversePath [
            true
            "strict"
          ];
        message = ''
          programs.metacubexd-desktop.tunMode requires
          networking.firewall.checkReversePath to be false or "loose".
        '';
      }
    ];

    networking.firewall.checkReversePath = lib.mkIf cfg.tunMode (lib.mkDefault "loose");
    boot.kernelModules = lib.mkIf cfg.tunMode [ "tun" ];

    systemd.services.metacubexd-helper = lib.mkIf cfg.tunMode {
      description = "MetaCubeXD TUN helper";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      # Generate at service startup, never in a derivation or a unit file.
      preStart = ''
        umask 077
        ${pkgs.openssl}/bin/openssl rand -hex 32 > /run/metacubexd-helper/secret
      '';
      serviceConfig = {
        Type = "exec";
        ExecStart = "${cfg.package}/bin/metacubexd-helper";
        User = if userExists then cfg.user else "nobody";
        Group = if userExists then helperUser.group else "nogroup";
        RuntimeDirectory = "metacubexd-helper";
        RuntimeDirectoryMode = "0700";
        UMask = "0077";
        Restart = "on-failure";
        KillMode = "control-group";
        TimeoutStopSec = 15;

        AmbientCapabilities = capabilities;
        CapabilityBoundingSet = capabilities;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        # Mihomo writes its geo data and caches beside the user's profiles.
        ReadWritePaths = lib.optional userExists helperUser.home;
        PrivateTmp = true;
        PrivateDevices = false;
        DevicePolicy = "closed";
        DeviceAllow = [ "/dev/net/tun rw" ];
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        LockPersonality = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
          "AF_PACKET"
        ];
        SystemCallArchitectures = "native";
      };
    };
  };

  meta.maintainers = with lib.maintainers; [ vertigo-red ];
}
