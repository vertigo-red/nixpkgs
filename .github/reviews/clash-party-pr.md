# Proposed title

clash-party: init at 2.0.4; mihomo-alpha, mihomo-smart: init

# Proposed body — requires the submitter's review

Add Clash Party 2.0.4, a Mihomo desktop client with profile management,
Sub-Store and stable/development/Smart core selection. Package `mihomo-alpha`
and `mihomo-smart` independently from pinned source revisions, and build the
GUI and native sysproxy binding from source. Electron, stable Mihomo, geodata
and Sub-Store come from Nixpkgs. Application/core self-updates are disabled.

The new `programs.clash-party` module provides installation, graphical
autostart and optional TUN capability wrappers restricted to an explicit
group. The GUI and core processes retain the user's UID. Documentation,
release notes and package/NixOS tests accompany the module.

This reintroduces the application previously known as Mihomo Party.
It was removed in https://github.com/NixOS/nixpkgs/pull/435188 following
licensing concerns. This change uses the currently published GPL-3.0 source
trees and builds all three cores from source; it does not establish that
the previous upstream concerns have been resolved. Please review whether
reintroduction is acceptable. The old removed-package alias is unchanged.
Both selected core READMEs also include a condition about downstream use of
the `mihomo` name. Its applicability to the Smart fork and variant package
names needs review alongside the previous removal; a GPL LICENSE file alone
does not settle that question.

Upstream: https://github.com/mihomo-party-org/clash-party
Release: https://github.com/mihomo-party-org/clash-party/releases/tag/v2.0.4
Validation: https://github.com/vertigo-red/nixpkgs/actions/runs/40311709916

Both architectures passed sandbox builds, offline Go unit tests, GUI
formatting/lint/type checks, 543 GUI unit tests (1 skipped), Electron UI,
Sub-Store API/frontend and switching among all three cores. On x86_64,
NixOS tests additionally checked authenticated HTTP/SOCKS for both new cores
and group isolation/non-root TUN creation for stable, Alpha and Smart.
ARM NixOS VM tests and `nixpkgs-review` were not run.

AI assistance: Codex (OpenAI GPT-6) was used to prepare the packaging,
module, tests, commit messages and this draft. The submitter must review
and take responsibility for the contribution before submitting it.

## Things done

<!-- Automated results below are verified; the submitter still needs to review the contribution and complete the first two items. -->

- [ ] Fits [CONTRIBUTING.md], [pkgs/README.md], [maintainers/README.md] and other READMEs.
- [ ] Follows the [automation/AI policy].
- Built on platform:
  - [x] x86_64-linux
  - [x] aarch64-linux
  - [ ] aarch64-darwin
- Tested, as applicable:
  - [x] Basic functionality of all binary files, usually in `./result/bin/`.
  - [ ] Ran `nixpkgs-review` on this PR. See [nixpkgs-review usage].
  - [x] [Package tests] at `passthru.tests`.
  - [x] [NixOS tests] in [nixos/tests].
  - [ ] Tests in [lib/tests] or [pkgs/test] for functions and "core" functionality.
- Nixpkgs Release Notes
  - [ ] Package update: when the change is major or breaking.
- NixOS Release Notes
  - [x] Module addition: when adding a new NixOS module.
  - [ ] Module update: when the change is significant.

[Package tests]: https://github.com/NixOS/nixpkgs/blob/master/pkgs/README.md#package-tests
[NixOS tests]: https://nixos.org/manual/nixos/unstable/index.html#sec-nixos-tests
[nixpkgs-review usage]: https://github.com/Mic92/nixpkgs-review#usage
[CONTRIBUTING.md]: https://github.com/NixOS/nixpkgs/blob/master/CONTRIBUTING.md
[automation/AI policy]: https://github.com/NixOS/nixpkgs/blob/master/CONTRIBUTING.md#automationai-policy
[lib/tests]: https://github.com/NixOS/nixpkgs/blob/master/lib/tests
[maintainers/README.md]: https://github.com/NixOS/nixpkgs/blob/master/maintainers/README.md
[nixos/tests]: https://github.com/NixOS/nixpkgs/blob/master/nixos/tests
[pkgs/README.md]: https://github.com/NixOS/nixpkgs/blob/master/pkgs/README.md
[pkgs/test]: https://github.com/NixOS/nixpkgs/blob/master/pkgs/test
