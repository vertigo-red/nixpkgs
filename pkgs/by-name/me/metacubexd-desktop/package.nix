{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_10,
  nodejs,
  electron_43-bin,
  mihomo,
  glib,
  gsettings-desktop-schemas,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  wrapGAppsHook3,
  writableTmpDirAsHomeHook,
  nix-update-script,
  nixosTests,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "metacubexd-desktop";
  version = "1.273.1";

  src = fetchFromGitHub {
    owner = "MetaCubeX";
    repo = "metacubexd";
    tag = "v${finalAttrs.version}";
    hash = "sha256-F6gjJLmkYUJCcRhT59QzLd5mB6yxQfz5Gh/Ca39cvR4=";
  };

  patches = [ ./nixos-integration.patch ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 4;
    hash = lib.fakeHash;
  };

  nativeBuildInputs = [
    nodejs
    pnpm_10
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
    NUXT_TELEMETRY_DISABLED = "1";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
    # Rolldown/Oxc's native Node modules need the compiler's C++ runtime.
    LD_LIBRARY_PATH = lib.makeLibraryPath [ stdenv.cc.cc.lib ];
  };

  postPatch = ''
    # Bundle the agent and its JavaScript dependencies; Electron and Node
    # builtins remain external. No node_modules tree is needed at runtime.
    substituteInPlace apps/desktop/electron.vite.config.ts \
      --replace-fail "plugins: [externalizeDepsPlugin({ exclude: ['@metacubexd/agent'] })]" \
        "plugins: []"

    # @nuxt/fonts downloads Google fonts during generation. Use system fonts.
    substituteInPlace packages/ui/nuxt.config.ts \
      --replace-fail "    '@nuxt/fonts'," ""
  '';

  buildPhase = ''
    runHook preBuild

    pnpm --filter @metacubexd/ui generate:desktop
    pnpm --filter @metacubexd/desktop copy:renderer
    pnpm --filter @metacubexd/desktop build

    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck

    pnpm --filter @metacubexd/config-editor test
    pnpm --filter @metacubexd/agent test
    pnpm --filter @metacubexd/desktop test

    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    appDir=$out/share/metacubexd-desktop
    mkdir -p "$appDir/resources" "$appDir/build"
    cp -r apps/desktop/{out,renderer,package.json} "$appDir/"
    cp apps/desktop/resources/{default-config.yaml,tray*.png} "$appDir/resources/"
    cp apps/desktop/build/icon.png "$appDir/build/"
    ln -s ${lib.getExe mihomo} "$appDir/resources/mihomo"

    for icon in apps/desktop/build/icons/*.png; do
      size=$(basename "$icon" .png)
      install -Dm644 "$icon" "$out/share/icons/hicolor/$size/apps/metacubexd-desktop.png"
    done

    makeWrapper ${lib.getExe electron_43-bin} "$out/bin/metacubexd-desktop" \
      --add-flags "$appDir" \
      --prefix PATH : ${lib.makeBinPath [ glib ]} \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      "''${gappsWrapperArgs[@]}"

    # The helper uses plain Node, with privileges supplied only by systemd.
    makeWrapper ${lib.getExe nodejs} "$out/bin/metacubexd-helper" \
      --add-flags "$appDir/out/helper/index.js" \
      --set MCXD_NIX_MIHOMO ${lib.getExe mihomo} \
      --set MCXD_HELPER_SOCKET /run/metacubexd-helper/helper.sock \
      --set MCXD_HELPER_SECRET_FILE /run/metacubexd-helper/secret

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "metacubexd-desktop";
      desktopName = "MetaCubeXD";
      genericName = "Proxy Client";
      comment = "Manage Mihomo profiles, proxies and TUN connections";
      exec = "metacubexd-desktop %U";
      icon = "metacubexd-desktop";
      startupWMClass = "metacubexd";
      categories = [ "Network" ];
      mimeTypes = [
        "x-scheme-handler/clash"
        "x-scheme-handler/clashmeta"
      ];
    })
  ];

  passthru = {
    inherit mihomo;
    tests.nixos = nixosTests.metacubexd-desktop;
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Mihomo desktop client with profile management and TUN support";
    homepage = "https://github.com/MetaCubeX/metacubexd";
    changelog = "https://github.com/MetaCubeX/metacubexd/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ vertigo-red ];
    mainProgram = "metacubexd-desktop";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
