{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage {
  pname = "clash-party-sysproxy";
  version = "0.1.3";

  src = fetchFromGitHub {
    owner = "mihomo-party-org";
    repo = "sysproxy-rs-opti";
    tag = "v0.1.3";
    hash = "sha256-r9nIkg0x3p8iBpzGKUJ5EiZ9UdLZ3jYNV66/VBDK27E=";
  };

  # Upstream does not commit its lockfile. Keep our resolved dependency set.
  cargoLock.lockFile = ./sysproxy-cargo.lock;
  postPatch = ''
    cp ${./sysproxy-cargo.lock} Cargo.lock
  '';

  # The upstream tests change the running desktop's proxy settings.
  doCheck = false;

  installPhase = ''
    runHook preInstall
    install -Dm755 target/${stdenv.hostPlatform.rust.rustcTarget}/release/libsysproxy.so $out/lib/sysproxy.node
    runHook postInstall
  '';

  meta = {
    description = "Clash Party's native system proxy binding";
    homepage = "https://github.com/mihomo-party-org/sysproxy-rs-opti";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ vertigo-red ];
    platforms = lib.platforms.linux;
  };
}
