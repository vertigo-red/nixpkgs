{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
  nixosTests,
}:

buildGoModule (finalAttrs: {
  pname = "mihomo-smart";
  # Use the latest numbered tag inherited by this rolling development fork.
  version = "1.19.9-unstable-2026-10-21";

  src = fetchFromGitHub {
    owner = "vernesong";
    repo = "mihomo";
    rev = "462455136157a760937c666bba71afe33b1a809e";
    hash = "sha256-tcPy8woJejhMG13fki87aeXyazIyfiWcHTGwrcHC99s=";
  };

  vendorHash = "sha256-FQ02hty2kpiqnxG+LLqtYLmgO9C+ZZK6JWNmYW5h/W8=";
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
    mv $out/bin/mihomo $out/bin/mihomo-smart
  '';

  passthru = {
    # Keep the Smart banner used by clients to identify the core flavor.
    upstreamVersion = "alpha-smart-${lib.substring 0 7 finalAttrs.src.rev}";
    tests.nixos = nixosTests.mihomo-smart;
    updateScript = nix-update-script { extraArgs = [ "--version=branch=Alpha" ]; };
  };

  meta = {
    description = "Rule-based proxy and tunnel with automatic proxy selection";
    homepage = "https://github.com/vernesong/mihomo";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ vertigo-red ];
    mainProgram = "mihomo-smart";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
