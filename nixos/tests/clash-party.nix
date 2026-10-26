{ pkgs, ... }:
{
  name = "clash-party";
  meta.maintainers = with pkgs.lib.maintainers; [ vertigo-red ];

  nodes.machine = { pkgs, ... }: {
    programs.clash-party = {
      enable = true;
      tunMode = true;
      group = "clash-party";
    };
    users.users.alice = {
      isNormalUser = true;
      extraGroups = [ "clash-party" ];
    };
    users.users.bob.isNormalUser = true;
    environment.systemPackages = [
      pkgs.curl
      pkgs.libcap
    ];
    virtualisation.memorySize = 2048;

    systemd.services."clash-party-core-test@" = {
      serviceConfig = {
        User = "alice";
        StateDirectory = "clash-party-test";
        ExecStart = "/run/wrappers/bin/clash-party-%i -d /var/lib/clash-party-test -f /etc/clash-party-test.yaml";
      };
    };
    environment.etc."clash-party-test.yaml".text = ''
      mixed-port: 17890
      external-controller: 127.0.0.1:19090
      mode: direct
      log-level: debug
      tun:
        enable: true
        device: party-test
        stack: system
        address: [198.18.0.1/30]
        auto-route: false
        auto-detect-interface: false
    '';
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    with subtest("Only the selected group can execute the privileged cores"):
        for core in ["mihomo", "mihomo-alpha", "mihomo-smart"]:
            wrapper = f"/run/wrappers/bin/clash-party-{core}"
            machine.succeed(f"getcap {wrapper} | grep cap_net_admin")
            machine.succeed(f"su - alice -c '{wrapper} -v'")
            machine.fail(f"su - bob -c '{wrapper} -v'")

    for core in ["mihomo", "mihomo-alpha", "mihomo-smart"]:
        with subtest(f"{core} creates a real TUN device without running as root"):
            unit = f"clash-party-core-test@{core}"
            machine.succeed(f"systemctl start {unit}")
            machine.wait_for_open_port(19090)
            machine.wait_until_succeeds("ip link show party-test")
            machine.succeed("curl --fail --max-time 5 http://127.0.0.1:19090/version | grep version")
            pid = machine.succeed(f"systemctl show -p MainPID --value {unit}").strip()
            uid = machine.succeed("id -u alice").strip()
            machine.succeed(f"grep -P '^Uid:\\s+{uid}\\s+{uid}\\s+{uid}\\s+{uid}$' /proc/{pid}/status")
            expected = "mihomo" if core == "mihomo" else core
            actual = machine.succeed(f"readlink /proc/{pid}/exe | xargs basename").strip()
            assert actual == expected, (core, actual)
            machine.succeed(f"systemctl stop {unit}")
            machine.wait_until_fails("ip link show party-test")
  '';
}
