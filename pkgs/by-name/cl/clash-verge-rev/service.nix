{
  lib,
  rustPlatform,
  fetchFromGitHub,
  meta,
  mihomo,
  procps,
  replaceVars,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "clash-verge-service-ipc";
  version = "2.7.6";

  src = fetchFromGitHub {
    owner = "clash-verge-rev";
    repo = "clash-verge-service-ipc";
    tag = "v${finalAttrs.version}";
    hash = "sha256-4YFRonC0nYuh16djiXuZszSoH06x49RVrtLcBnsI7VI=";
  };

  patches = [
    # Pin privileged core execution to the immutable packaged mihomo. Let the
    # NixOS module manage the runtime directory and keep socket access group-only.
    (replaceVars ./patch-service-directory.patch {
      mihomo = lib.getExe mihomo;
    })
  ];

  cargoHash = "sha256-Lx/Pj4Aev4aR0KQg/cdOXt+gx+s2XAgPG+mr+6w9dnY=";

  buildFeatures = [
    "standalone"
  ];

  nativeCheckInputs = [
    procps
  ];
  # build test helper binaries for tests
  preCheck = ''
    cargo build --features=standalone,test
  '';
  checkFeatures = [
    "standalone"
    "test"
    "client"
  ];
  inherit meta;
})
