{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.clash-party;
  package =
    if cfg.tunMode then
      cfg.package.override {
        mihomoExecutable = "${config.security.wrapperDir}/clash-party-mihomo";
      }
    else
      cfg.package;
in
{
  options.programs.clash-party = {
    enable = lib.mkEnableOption "Clash Party";
    package = lib.mkPackageOption pkgs "clash-party" { };
    autoStart = lib.mkEnableOption "Clash Party auto launch";
    tunMode = lib.mkEnableOption "the network capabilities required by Clash Party's TUN mode";
    group = lib.mkOption {
      type = lib.types.str;
      default = "users";
      example = "wheel";
      description = ''
        Group allowed to run Clash Party's Mihomo core with network capabilities.
        Only members of this group can use TUN mode.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      package
    ]
    ++ lib.optional cfg.autoStart (
      pkgs.makeAutostartItem {
        name = "clash-party";
        inherit package;
      }
    );

    security.wrappers.clash-party-mihomo = lib.mkIf cfg.tunMode {
      source = lib.getExe cfg.package.mihomo;
      owner = "root";
      group = cfg.group;
      permissions = "u+rx,g+rx,o-rwx";
      capabilities = "cap_net_bind_service,cap_net_raw,cap_net_admin=+ep";
    };

    networking.firewall.checkReversePath = lib.mkIf cfg.tunMode (lib.mkDefault "loose");

    assertions = [
      {
        assertion =
          cfg.tunMode
          -> !builtins.elem config.networking.firewall.checkReversePath [
            true
            "strict"
          ];
        message = ''
          programs.clash-party.tunMode requires networking.firewall.checkReversePath
          to be false or "loose".
        '';
      }
    ];
  };

  meta = {
    maintainers = pkgs.clash-party.meta.maintainers;
    doc = ./clash-party.md;
  };
}
