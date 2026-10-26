{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
  nixosTests,
}:

buildGoModule (finalAttrs: {
  pname = "mihomo-alpha";
  version = "1.19.33-unstable-2026-10-26";

  src = fetchFromGitHub {
    owner = "MetaCubeX";
    repo = "mihomo";
    rev = "b6a15182c2870f42eb04df7b763171fd3e2f1da4";
    hash = "sha256-Rgos1seQeh526pu6rJt0rlz+bK0ik+aLWAwH9kxl3Uw=";
  };

  vendorHash = "sha256-Jf0I0unKeHftwWieSZ+MFXxqDogqBGD4mnEug+WKHgQ=";
  subPackages = [ "." ];
  env.CGO_ENABLED = "0";
  tags = [ "with_gvisor" ];
  ldflags = [
    "-s"
    "-w"
    "-X github.com/metacubex/mihomo/constant.Version=${finalAttrs.passthru.upstreamVersion}"
  ];

  # The top-level integration suite downloads software and uses the Internet.
  # Run the offline unit tests here and exercise proxies in the NixOS VM test.
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    go test -tags=with_gvisor -p "$NIX_BUILD_CORES" -timeout 120s ./common/...
    runHook postCheck
  '';

  postInstall = ''
    mv $out/bin/mihomo $out/bin/mihomo-alpha
  '';

  passthru = {
    # Keep the development banner used by clients to identify the core flavor.
    upstreamVersion = "alpha-${lib.substring 0 7 finalAttrs.src.rev}";
    tests.nixos = nixosTests.mihomo-alpha;
    updateScript = nix-update-script { extraArgs = [ "--version=branch=Alpha" ]; };
  };

  meta = {
    description = "Rule-based proxy and tunnel from the development branch";
    homepage = "https://github.com/MetaCubeX/mihomo/tree/Alpha";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ vertigo-red ];
    mainProgram = "mihomo-alpha";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
