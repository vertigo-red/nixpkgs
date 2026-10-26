{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.clash-party;
in
{
  options.programs.clash-party = {
    enable = lib.mkEnableOption "Clash Party";
    package = lib.mkPackageOption pkgs "clash-party" { };
    autoStart = lib.mkEnableOption "Clash Party at login";
    tunMode = lib.mkEnableOption "the Mihomo capabilities needed for TUN and local DNS" // {
      description = ''
        Whether members of the configured group may start the packaged
        Mihomo cores with network capabilities for TUN and local DNS.
        The GUI runs without those capabilities. Add intended users to
        this group through {option}`users.users.<name>.extraGroups`.
      '';
    };
    group = lib.mkOption {
      type = lib.types.str;
      default = "clash-party";
      example = "vpn";
      description = ''
        Group allowed to run the Mihomo cores with network capabilities.
        Users of TUN mode must belong to this group. The module creates
        the group; add intended users through users.users.<name>.extraGroups.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ]
    ++ lib.optional cfg.autoStart (
      pkgs.makeAutostartItem {
        name = "clash-party";
        package = cfg.package;
      }
    );

    users.groups = lib.mkIf cfg.tunMode { ${cfg.group} = { }; };
    boot.kernelModules = lib.optional cfg.tunMode "tun";

    # The GUI stays unprivileged. Only the three pinned core binaries can
    # acquire capabilities, via NixOS-managed wrappers outside /nix/store.
    security.wrappers = lib.mkIf cfg.tunMode (
      lib.mapAttrs'
        (
          name: package:
          lib.nameValuePair "clash-party-${name}" {
            source = lib.getExe package;
            owner = "root";
            group = cfg.group;
            permissions = "u+rx,g+rx,o-rwx";
            capabilities = "cap_net_admin,cap_net_raw,cap_net_bind_service=+ep";
          }
        )
        {
          mihomo = cfg.package.mihomo;
          mihomo-alpha = cfg.package.mihomo-alpha;
          mihomo-smart = cfg.package.mihomo-smart;
        }
    );

    networking.firewall.checkReversePath = lib.mkIf cfg.tunMode (lib.mkDefault "loose");
    assertions = [
      {
        assertion =
          cfg.tunMode
          -> (
            config.networking.firewall.checkReversePath != true
            && config.networking.firewall.checkReversePath != "strict"
          );
        message = "programs.clash-party.tunMode requires networking.firewall.checkReversePath = false or \"loose\".";
      }
    ];
  };

  meta = {
    maintainers = with lib.maintainers; [ vertigo-red ];
    doc = ./clash-party.md;
  };
}
