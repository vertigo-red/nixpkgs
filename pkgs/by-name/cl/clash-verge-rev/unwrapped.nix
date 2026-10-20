{
  pname,
  version,
  src,
  meta,

  pnpm-hash,
  vendor-hash,

  rustPlatform,
  cargo-tauri,
  jq,
  moreutils,
  nodejs,
  pkg-config,
  pnpm_12,
  fetchPnpmDeps,
  pnpmConfigHook,

  glib,
  kdePackages,
  libayatana-appindicator,
  libsForQt5,
  libsoup_3,
  openssl,
  webkitgtk_4_1,
}:
rustPlatform.buildRustPackage {
  inherit version src meta;
  pname = "${pname}-unwrapped";

  cargoHash = vendor-hash;

  # Use the mihomo supplied by Nixpkgs; override it for a newer core.
  patches = [ ./disable-alpha-core.patch ];

  pnpmDeps = fetchPnpmDeps {
    inherit
      pname
      version
      src
      ;
    pnpm = pnpm_12;
    fetcherVersion = 4;
    hash = pnpm-hash;
  };

  env = {
    OPENSSL_NO_VENDOR = 1;
  };

  postPatch = ''
    # This macOS-only patch is unused by Cargo.lock but Cargo still tries to
    # fetch its unvendored Git source during offline builds.
    substituteInPlace Cargo.toml \
      --replace-fail 'tray-icon = { git = "https://github.com/Tunglies/tray-icon.git", branch = "fix/macos-27-click-reentrancy" }' ""

    substituteInPlace $cargoDepsCopy/*/libappindicator-sys-*/src/lib.rs \
      --replace-fail "libayatana-appindicator3.so.1" "${libayatana-appindicator}/lib/libayatana-appindicator3.so.1"

    substituteInPlace $cargoDepsCopy/*/sysproxy-*/src/linux.rs \
      --replace-fail '"gsettings"' '"${glib.bin}/bin/gsettings"' \
      --replace-fail '"kreadconfig6"' '"${kdePackages.kconfig}/bin/kreadconfig6"' \
      --replace-fail '"kwriteconfig6"' '"${kdePackages.kconfig}/bin/kwriteconfig6"'

    # this file tries to override the linker used when compiling for certain platforms
    rm .cargo/config.toml

    # disable updater and don't try to bundle helper binaries
    jq '
      .bundle.createUpdaterArtifacts = false |
      del(.bundle.resources) |
      del(.bundle.externalBin)
    ' src-tauri/tauri.conf.json | sponge src-tauri/tauri.conf.json

    jq 'del(.bundle.externalBin)' src-tauri/tauri.linux.conf.json | sponge src-tauri/tauri.linux.conf.json
  '';

  nativeBuildInputs = [
    cargo-tauri.hook
    jq
    moreutils
    nodejs
    pkg-config
    pnpmConfigHook
    pnpm_12
  ];

  buildInputs = [
    libayatana-appindicator
    libsoup_3
    openssl
    webkitgtk_4_1
  ];

  # make sure the .desktop file name does not contain whitespace,
  # so that the service can register it as an auto-start item
  postInstall = ''
    mv $out/share/applications/Clash\ Verge.desktop $out/share/applications/clash-verge.desktop
  '';
}
