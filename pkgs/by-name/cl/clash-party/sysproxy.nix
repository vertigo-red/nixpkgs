{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  glib,
  dconf,
  kdePackages,
  nodejs,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "clash-party-sysproxy";
  version = "0.1.3";

  src = fetchFromGitHub {
    owner = "mihomo-party-org";
    repo = "sysproxy-rs-opti";
    tag = "v${finalAttrs.version}";
    hash = "sha256-r9nIkg0x3p8iBpzGKUJ5EiZ9UdLZ3jYNV66/VBDK27E=";
  };

  # Upstream does not include a lockfile.
  cargoLock.lockFile = ./sysproxy-Cargo.lock;

  postPatch = ''
    cp ${./sysproxy-Cargo.lock} Cargo.lock
    substituteInPlace src/linux.rs \
      --replace-fail '"gsettings"' '"${glib.bin}/bin/gsettings"' \
      --replace-fail '"dconf"' '"${dconf}/bin/dconf"' \
      --replace-fail '"kreadconfig5"' '"${kdePackages.kconfig}/bin/kreadconfig6"' \
      --replace-fail '"kwriteconfig5"' '"${kdePackages.kconfig}/bin/kwriteconfig6"' \
      --replace-fail '"kreadconfig6"' '"${kdePackages.kconfig}/bin/kreadconfig6"' \
      --replace-fail '"kwriteconfig6"' '"${kdePackages.kconfig}/bin/kwriteconfig6"'
  '';

  cargoBuildFlags = [ "--lib" ];

  # The upstream tests read and modify the current desktop's proxy settings.
  doCheck = false;

  installPhase = ''
    runHook preInstall
    install -Dm755 target/${stdenv.hostPlatform.rust.rustcTarget}/release/libsysproxy.so $out/lib/sysproxy.node
    runHook postInstall
  '';

  nativeInstallCheckInputs = [ nodejs ];
  doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck
    node -e '
      const binding = require(process.argv[1]);
      for (const name of ["getSystemProxy", "setSystemProxy", "triggerManualProxy", "triggerAutoProxy"]) {
        if (typeof binding[name] !== "function") throw new Error(`Missing export: ''${name}`);
      }
    ' "$out/lib/sysproxy.node"
    runHook postInstallCheck
  '';

  meta = {
    description = "Native system proxy binding for Clash Party";
    homepage = "https://github.com/mihomo-party-org/sysproxy-rs-opti";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ vertigo-red ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
