{ pkgs, lib, ... }:
let
  client = pkgs.writeText "metacubexd-helper-client.py" ''
    import json
    import pathlib
    import signal
    import socket

    secret = pathlib.Path('/run/metacubexd-helper/secret').read_text().strip()
    connection = socket.socket(socket.AF_UNIX)
    connection.settimeout(10)
    connection.connect('/run/metacubexd-helper/helper.sock')
    stream = connection.makefile('rwb', buffering=0)

    def request(kind, **fields):
        message = dict(type=kind, version='1', secret=secret)
        message.update(fields)
        stream.write((json.dumps(message) + '\n').encode())
        return json.loads(stream.readline())

    assert not request('ping', secret='incorrect')['ok']
    assert request('getVersion')['version'] == '1'
    options = dict(
        homeDir='/home/alice/mihomo',
        configPath='/home/alice/config.yaml',
    )
    # Authenticated clients still cannot launch arbitrary binaries with caps.
    result = request('startKernel', binaryPath='${pkgs.coreutils}/bin/false', **options)
    assert not result['ok'] and 'provided by NixOS' in result['error'], result
    result = request('startKernel', binaryPath='/home/alice/unsafe-kernel', **options)
    assert not result['ok'], result
    result = request('startKernel', binaryPath='${lib.getExe pkgs.metacubexd-desktop.mihomo}', **options)
    assert result['ok'] and result['running'], result
    pathlib.Path('/run/metacubexd-test-client/ready').touch()
    # Retain ownership of the kernel until the test stops this client.
    signal.pause()
  '';
in
{
  name = "metacubexd-desktop";
  meta.maintainers = with lib.maintainers; [ vertigo-red ];

  nodes.machine = {
    users.users.alice.isNormalUser = true;
    users.users.bob.isNormalUser = true;

    programs.metacubexd-desktop = {
      enable = true;
      tunMode = true;
      user = "alice";
    };

    environment.systemPackages = [
      pkgs.curl
      pkgs.python3
      pkgs.util-linux
    ];

    services.nginx = {
      enable = true;
      statusPage = true;
      defaultHTTPListenPort = 18888;
    };

    systemd.services.metacubexd-test-client = {
      serviceConfig = {
        User = "alice";
        RuntimeDirectory = "metacubexd-test-client";
        ExecStart = "${pkgs.python3}/bin/python ${client}";
      };
    };

    systemd.tmpfiles.rules = [ "d /home/alice/mihomo 0700 alice users -" ];
    environment.etc."metacubexd-test.yaml".text = ''
      mixed-port: 17890
      external-controller: 127.0.0.1:19090
      allow-lan: false
      mode: rule
      log-level: debug
      find-process-mode: off
      geo-auto-update: false
      proxies: []
      rules:
        - MATCH,DIRECT
      tun:
        enable: true
        device: MCXDTest
        stack: system
        auto-route: true
        auto-detect-interface: true
        dns-hijack: []
    '';
  };

  testScript = ''
    machine.wait_for_unit("metacubexd-helper.service")
    machine.wait_for_unit("nginx.service")
    machine.wait_until_succeeds("test -S /run/metacubexd-helper/helper.sock")
    machine.succeed("test $(stat -c %a /run/metacubexd-helper) = 700")
    machine.succeed("test $(stat -c %a /run/metacubexd-helper/secret) = 600")
    machine.succeed("test $(systemctl show -p User --value metacubexd-helper.service) = alice")

    with subtest("only the configured user can reach the helper"):
        machine.fail("runuser -u bob -- cat /run/metacubexd-helper/secret")
        machine.fail("runuser -u bob -- python -c 'import socket; s=socket.socket(socket.AF_UNIX); s.connect(\"/run/metacubexd-helper/helper.sock\")'")

    machine.succeed("install -o alice -g users -m 600 /etc/metacubexd-test.yaml /home/alice/config.yaml")
    machine.succeed("install -o alice -g users -m 755 ${pkgs.coreutils}/bin/false /home/alice/unsafe-kernel")

    with subtest("authenticated IPC starts an actual TUN with the packaged Mihomo"):
        machine.start_job("metacubexd-test-client.service")
        machine.wait_until_succeeds("test -f /run/metacubexd-test-client/ready")
        machine.wait_for_open_port(17890)
        machine.wait_for_open_port(19090)
        machine.wait_until_succeeds("ip link show MCXDTest")
        machine.succeed("curl --fail --max-time 10 --proxy http://127.0.0.1:17890 http://127.0.0.1:18888/nginx_status")
        machine.succeed("curl --fail --max-time 10 --proxy socks5h://127.0.0.1:17890 http://127.0.0.1:18888/nginx_status")

    with subtest("a disconnected application tears down TUN"):
        machine.stop_job("metacubexd-test-client.service")
        machine.wait_until_fails("ip link show MCXDTest")
        machine.wait_until_fails("curl --fail --max-time 1 http://127.0.0.1:19090")

    with subtest("service restart creates a usable socket and a fresh token"):
        machine.succeed("cp /run/metacubexd-helper/secret /tmp/old-token; chmod 600 /tmp/old-token")
        machine.succeed("systemctl restart metacubexd-helper.service")
        machine.wait_until_succeeds("test -S /run/metacubexd-helper/helper.sock")
        machine.fail("cmp /tmp/old-token /run/metacubexd-helper/secret")
        machine.start_job("metacubexd-test-client.service")
        machine.wait_for_open_port(19090)
        machine.wait_until_succeeds("ip link show MCXDTest")
        machine.stop_job("metacubexd-test-client.service")
        machine.wait_until_fails("ip link show MCXDTest")
  '';
}
