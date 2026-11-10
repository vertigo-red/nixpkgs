{
  lib,
  stdenvNoCC,
  callPackage,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_11,
  nodejs,
  electron_43,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  wrapGAppsHook3,
  gsettings-desktop-schemas,
  libayatana-appindicator,
  libcap,
  wl-clipboard,
  xdg-utils,
  noto-fonts-color-emoji,
  mihomo,
  dbip-asn-lite,
  dbip-country-lite,
  v2ray-geoip,
  v2ray-domain-list-community,
  sub-store,
  sub-store-frontend,
  nix-update-script,
  # Set by the NixOS module when it provides a capability wrapper for this core.
  mihomoExecutable ? null,
}:
let
  pnpm = pnpm_11;
  electron = electron_43;
  sysproxy = callPackage ./sysproxy.nix { };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "clash-party";
  version = "2.0.4";

  src = fetchFromGitHub {
    owner = "mihomo-party-org";
    repo = "clash-party";
    tag = "v${finalAttrs.version}";
    hash = "sha256-FbftzeEJ81xEnkOU4YRNHPWdwC2tZQFeuUELKr4v+vM=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    fetcherVersion = 5;
    hash = "sha256-XdHF94XPjSkBGp1W/y0XSgILSOBtVCSSmO4jx7faQ8o=";
  };

  patches = [ ./nix-integration.patch ];

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    makeWrapper
    copyDesktopItems
    wrapGAppsHook3
  ];

  buildInputs = [ gsettings-desktop-schemas ];

  strictDeps = true;
  dontWrapGApps = true;

  env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

  postPatch = ''
    substituteInPlace src/main/utils/dirs.ts src/native/sysproxy/index.js \
      --replace-fail '@resources@' "$out/share/clash-party/resources"
    substituteInPlace src/main/utils/dirs.ts \
      --replace-fail '@executable@' "$out/bin/clash-party" \
      --replace-fail '@mihomoExecutable@' '${
        if mihomoExecutable == null then lib.getExe mihomo else mihomoExecutable
      }' \
      --replace-fail '@mihomo@' '${lib.getExe mihomo}'
    substituteInPlace src/main/core/permissions.ts \
      --replace-fail '@getcap@' '${lib.getExe' libcap "getcap"}'

    # prepare.mjs downloads unpinned binaries and data; supply these through Nix instead.
    cp ${noto-fonts-color-emoji}/share/fonts/noto/NotoColorEmoji.ttf \
      src/renderer/src/assets/NotoColorEmoji.ttf
  '';

  buildPhase = ''
    runHook preBuild

    # file-icon's prebuilt helper is only used on macOS.
    rm -f node_modules/file-icon/file-icon

    pnpm exec electron-vite build
    pnpm exec electron-builder --linux --dir \
      -c.electronDist=${electron.dist} \
      -c.electronVersion=${electron.version} \
      -c.npmRebuild=false

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/clash-party
    cp -r dist/linux-*/resources $out/share/clash-party/

    resources=$out/share/clash-party/resources
    rm -f "$resources/default_app.asar"
    mkdir -p "$resources"/{files,sidecar}
    ln -s ${sysproxy}/lib/sysproxy.node \
      "$resources/sidecar/sysproxy.linux-${stdenvNoCC.hostPlatform.node.arch}-gnu.node"
    ln -s ${lib.getExe mihomo} "$resources/sidecar/mihomo"
    ln -s ${dbip-asn-lite.mmdb} "$resources/files/ASN.mmdb"
    ln -s ${dbip-country-lite.mmdb} "$resources/files/country.mmdb"
    ln -s ${v2ray-geoip}/share/v2ray/geoip.dat "$resources/files/geoip.dat"
    ln -s ${v2ray-domain-list-community}/share/v2ray/geosite.dat "$resources/files/geosite.dat"
    ln -s ${sub-store}/share/sub-store/sub-store.bundle.js "$resources/files/sub-store.bundle.cjs"
    ln -s ${sub-store-frontend} "$resources/files/sub-store-frontend"

    install -Dm644 build/icon.png $out/share/icons/hicolor/512x512/apps/clash-party.png
    install -Dm644 ${./clash-party.xml} $out/share/mime/packages/clash-party.xml

    runHook postInstall
  '';

  postFixup = ''
    makeWrapper ${lib.getExe electron} $out/bin/clash-party \
      --add-flags "$out/share/clash-party/resources/app.asar" \
      --set-default ELECTRON_FORCE_IS_PACKAGED 1 \
      --set-default ELECTRON_IS_DEV 0 \
      --prefix PATH : ${
        lib.makeBinPath [
          wl-clipboard
          xdg-utils
        ]
      } \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libayatana-appindicator ]} \
      --inherit-argv0 \
      "''${gappsWrapperArgs[@]}"
  '';

  doInstallCheck = stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck

    # Load the packaged addon with Electron's Node runtime, without changing proxy settings.
    ELECTRON_RUN_AS_NODE=1 ${lib.getExe electron} -e '
      const path = require("node:path");
      const app = process.argv[1];
      const pkg = require(path.join(app, "package.json"));
      if (pkg.version !== "${finalAttrs.version}") throw new Error("Incorrect application version");
      const binding = require(path.join(app, "node_modules/sysproxy-rs"));
      if (typeof binding.setSystemProxy !== "function") throw new Error("Cannot load sysproxy in Electron");
    ' "$out/share/clash-party/resources/app.asar"

    runHook postInstallCheck
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "clash-party";
      desktopName = "Clash Party";
      genericName = "Proxy Client";
      comment = "GUI client based on Mihomo";
      exec = "clash-party %U";
      icon = "clash-party";
      startupWMClass = "mihomo-party";
      categories = [
        "Network"
        "Utility"
      ];
      keywords = [
        "proxy"
        "clash"
        "mihomo"
        "vpn"
      ];
      mimeTypes = [
        "x-scheme-handler/clash"
        "x-scheme-handler/mihomo"
        "application/x-clash-party-plugin"
      ];
    })
  ];

  passthru = {
    inherit mihomo sysproxy;
    updateScript = nix-update-script { extraArgs = [ "--use-github-releases" ]; };
  };

  meta = {
    description = "Mihomo GUI with profile management and TUN support";
    longDescription = ''
      Clash Party uses the Mihomo core and geodata provided by Nixpkgs.
      Core selection and in-application core updates are disabled; override
      the mihomo dependency to use a different core version.
      On NixOS, enable programs.clash-party.tunMode for TUN support.
    '';
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
