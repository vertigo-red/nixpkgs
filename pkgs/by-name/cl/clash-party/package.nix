{
  lib,
  stdenv,
  callPackage,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_11,
  nodejs,
  electron_43-bin,
  mihomo,
  mihomo-alpha,
  mihomo-smart,
  sub-store,
  sub-store-frontend,
  dbip-country-lite,
  v2ray-geoip,
  v2ray-domain-list-community,
  noto-fonts-color-emoji,
  glib,
  dconf,
  kdePackages,
  libcap,
  wl-clipboard,
  xdg-utils,
  procps,
  iproute2,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  wrapGAppsHook3,
  gsettings-desktop-schemas,
  writableTmpDirAsHomeHook,
  nixosTests,
  nix-update-script,
}:

let
  sysproxy = callPackage ./sysproxy.nix { };
  nodeArch =
    {
      x86_64-linux = "x64";
      aarch64-linux = "arm64";
    }
    .${stdenv.hostPlatform.system};
in
stdenv.mkDerivation (finalAttrs: {
  pname = "clash-party";
  version = "2.0.4";

  src = fetchFromGitHub {
    owner = "mihomo-party-org";
    repo = "clash-party";
    tag = "v${finalAttrs.version}";
    hash = "sha256-FbftzeEJ81xEnkOU4YRNHPWdwC2tZQFeuUELKr4v+vM=";
  };

  # Nix owns the immutable resources and core updates; the GUI stays unprivileged.
  patches = [ ./nixos-integration.patch ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-lYp+NAVEji5kwIcPHJP2GSLgMigssHouAwrTvVvHWvQ=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm_11
    pnpmConfigHook
    makeWrapper
    copyDesktopItems
    wrapGAppsHook3
    writableTmpDirAsHomeHook
  ];
  buildInputs = [ gsettings-desktop-schemas ];
  strictDeps = true;
  dontWrapGApps = true;

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
    LD_LIBRARY_PATH = lib.makeLibraryPath [ stdenv.cc.cc.lib ];
  };

  postPatch = ''
    cp ${noto-fonts-color-emoji}/share/fonts/noto/NotoColorEmoji.ttf src/renderer/src/assets/NotoColorEmoji.ttf
  '';

  buildPhase = ''
    runHook preBuild
    # Skip prepare.mjs: it downloads unpinned cores and resources.
    pnpm exec electron-vite build
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    pnpm exec prettier --check \
      src/main/core/mihomoApi.ts src/main/core/permissions.ts \
      src/main/resolve/autoUpdater.ts src/main/utils/dirs.ts \
      src/main/utils/github.ts src/native/sysproxy/index.js
    pnpm exec eslint \
      src/main/core/mihomoApi.ts src/main/core/permissions.ts \
      src/main/resolve/autoUpdater.ts src/main/utils/dirs.ts \
      src/main/utils/github.ts src/native/sysproxy/index.js
    pnpm run typecheck
    pnpm test
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    CI=true pnpm prune --prod --ignore-scripts --config.offline=true
    # Electron is supplied by nixpkgs. Its npm peer package and downloader
    # contain unused prebuilt native helpers for several architectures.
    rm -rf node_modules/.pnpm/electron@* node_modules/.pnpm/@electron-internal+extract-zip@*
    # This helper is macOS-only; Linux icon lookup uses Electron and XDG data.
    rm -f node_modules/file-icon/file-icon
    find node_modules -xtype l -delete
    appDir=$out/share/clash-party
    mkdir -p "$appDir/resources/sidecar" "$appDir/resources/files" "$appDir/resources"
    cp -r out node_modules package.json "$appDir/"
    cp -r resources/. "$appDir/resources/"
    install -Dm755 ${sysproxy}/lib/sysproxy.node \
      "$appDir/resources/sidecar/sysproxy.linux-${nodeArch}-gnu.node"
    ln -s ${lib.getExe mihomo} "$appDir/resources/sidecar/mihomo"
    ln -s ${lib.getExe mihomo-alpha} "$appDir/resources/sidecar/mihomo-alpha"
    ln -s ${lib.getExe mihomo-smart} "$appDir/resources/sidecar/mihomo-smart"
    cp ${dbip-country-lite.mmdb} "$appDir/resources/files/country.mmdb"
    cp ${v2ray-geoip}/share/v2ray/geoip.dat "$appDir/resources/files/geoip.dat"
    cp ${v2ray-domain-list-community}/share/v2ray/geosite.dat "$appDir/resources/files/geosite.dat"
    cp ${sub-store}/share/sub-store/sub-store.bundle.js "$appDir/resources/files/sub-store.bundle.cjs"
    cp -r ${sub-store-frontend} "$appDir/resources/files/sub-store-frontend"

    install -Dm644 build/icon.png "$out/share/icons/hicolor/512x512/apps/clash-party.png"
    # Upstream's tray and generated autostart entry use the historic icon name.
    ln -s clash-party.png "$out/share/icons/hicolor/512x512/apps/mihomo-party.png"
    install -Dm644 LICENSE "$out/share/licenses/clash-party/LICENSE"

    makeWrapper ${lib.getExe electron_43-bin} "$out/bin/clash-party" \
      --add-flags "$appDir" \
      --set CLASH_PARTY_RESOURCES "$appDir/resources" \
      --set CLASH_PARTY_EXECUTABLE "$out/bin/clash-party" \
      --set CLASH_PARTY_GETCAP ${lib.getExe' libcap "getcap"} \
      --prefix PATH : ${
        lib.makeBinPath [
          glib
          dconf
          kdePackages.kconfig
          libcap
          wl-clipboard
          xdg-utils
          procps
          iproute2
        ]
      } \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      "''${gappsWrapperArgs[@]}"

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "clash-party";
      desktopName = "Clash Party";
      genericName = "Proxy Client";
      comment = "Manage Mihomo profiles, proxies and TUN connections";
      exec = "clash-party %U";
      icon = "clash-party";
      startupWMClass = "mihomo-party";
      categories = [ "Network" ];
      mimeTypes = [
        "x-scheme-handler/clash"
        "x-scheme-handler/mihomo"
        "application/x-clash-party-plugin"
      ];
    })
  ];

  passthru = {
    inherit
      mihomo
      mihomo-alpha
      mihomo-smart
      sysproxy
      ;
    tests.nixos = nixosTests.clash-party;
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Mihomo desktop client with profile management, Sub-Store and Smart core support";
    homepage = "https://github.com/mihomo-party-org/clash-party";
    changelog = "https://github.com/mihomo-party-org/clash-party/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ vertigo-red ];
    mainProgram = "clash-party";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
