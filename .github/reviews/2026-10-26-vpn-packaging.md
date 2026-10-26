# Проверка подготовки VPN-пакетов к Nixpkgs PR

Дата: 2026-10-26. Подготовлено с помощью Codex (OpenAI GPT-6).
Это техническая проверка и материал для ревью ответственным автором PR.

## Clash Party, Mihomo Alpha и Mihomo Smart

Ветка: [`clash-party-packaging`](https://github.com/vertigo-red/nixpkgs/tree/clash-party-packaging).
Проверенная ревизия: `2f81bb8bb21e3b4905ee0882462fc61f7d597ee1`.
База: NixOS/nixpkgs `d6471495b69e4c0054040c1e7d84258710293542`.

История пересобрана без промежуточных исправлений и merge-коммитов:

| Коммит | Заголовок |
| --- | --- |
| `96c5e7f4dba5` | `maintainers: add vertigo-red` |
| `27d49053b81f` | `mihomo-alpha: init at 1.19.33-unstable-2026-10-26` |
| `8edfa5c6a482` | `mihomo-smart: init at 1.19.9-unstable-2026-10-21` |
| `50eb3413c6f1` | `clash-party: init at 2.0.4` |
| `2f81bb8bb21e` | `nixos/clash-party: init module` |

Все пять коммитов содержат `Assisted-by: Codex (OpenAI GPT-6)`.
Коммит приложения не ссылается на ещё не добавленный тест модуля.
Ветка `ci-builds` и инструкции личного Cachix не входят в исходную ветку PR.

Проверены `CONTRIBUTING.md`, `pkgs/README.md`, `maintainers/README.md`,
`nixos/README.md` и `.github/PULL_REQUEST_TEMPLATE.md` на указанной базе.
Заголовки, отдельный предшествующий коммит maintainer, разделение логических
изменений, by-name layout, реальные fixed-output hashes, лицензии в meta,
maintainers, mainProgram, update scripts, rationale патча, NixOS release note,
документация через `meta.doc` и `passthru.tests` приведены к этим правилам.

### Источники и поведение

| Пакет | Исходники | Ревизия |
| --- | --- | --- |
| Clash Party 2.0.4 | mihomo-party-org/clash-party | tag `v2.0.4` |
| mihomo-alpha | MetaCubeX/mihomo | `b6a15182c2870f42eb04df7b763171fd3e2f1da4` |
| mihomo-smart | vernesong/mihomo | `462455136157a760937c666bba71afe33b1a809e` |
| Native sysproxy binding | mihomo-party-org/sysproxy-rs-opti | tag `v0.1.3` |

Оба новых ядра собираются через `buildGoModule` с gVisor, а sysproxy — через
`buildRustPackage`. Готовые скачиваемые ядра удалены из рецепта. Smart закреплён
на опубликованном snapshot; HEAD его rolling-ветки намеренно не подменяет эту
ревизию. Версии snapshot основаны на последних подходящих numbered tags и датах
коммитов; runtime banners сохранены для распознавания типов ядер приложением.
У каждого ядра собственное имя executable, поэтому они могут стоять вместе.

GUI собирается из исходников и использует отдельный Electron из Nixpkgs,
а также Nixpkgs Sub-Store и geodata. Неиспользуемый npm Electron с его native
download helpers удаляется из runtime. Application/core self-updates отключены.
Ресурсы пакета неизменяемы; пользовательские копии данных доступны для записи.

Для новых ядер выбраны отдельные короткие рецепты. Общий builder пока добавил бы
слой косвенности для двух вариантов; override стабильного Mihomo связал бы их
обновление с меняющимися особенностями другого source tree. При появлении новых
вариантов повторяющуюся часть можно вынести в общий builder.

GUI работает от обычного пользователя. Только wrappers для трёх закреплённых
ядер получают network capabilities; доступ ограничен отдельной группой.
Для TUN требуется явное членство, например:

```nix
programs.clash-party = {
  enable = true;
  tunMode = true;
};
users.users."vertigo.red".extraGroups = [ "clash-party" ];
```

После изменения групп нужен новый сеанс входа. Модуль загружает `tun` и по
умолчанию выбирает loose reverse path filtering. Пользователи вне группы могут
использовать обычный proxy mode.

### Проверки и Cachix

Локально собраны оба ядра с offline Go unit tests и приложение с Prettier,
ESLint, полной проверкой типов и 543 успешными unit-тестами (1 skipped).
Локальная среда требует обходов ограничений host/container, поэтому результат
не выдаётся за проверку исходного рецепта в настоящем Nix sandbox.
Все три NixOS tests успешно вычислены; aarch64 derivations также вычислены.

CI: https://github.com/vertigo-red/nixpkgs/actions/runs/40311709916

Оба job завершились успешно на CI commit
`9e0a2e0c93a61024e27192bdd3a06f19e24ede8c`.

| Проверка | x86_64-linux | aarch64-linux |
| --- | --- | --- |
| История, trailers, Nix formatting | passed | passed |
| Sandbox builds, Go unit tests, GUI format/lint/types | passed | passed |
| GUI unit tests | 543 passed, 1 skipped | 543 passed, 1 skipped |
| Electron UI, preload IPC, Sub-Store API/frontend | passed | passed |
| GUI stable/Alpha/Smart switching | passed | passed |
| NixOS HTTP/SOCKS tests обоих новых ядер | passed | не запускались |
| NixOS group isolation и все три TUN core | passed | не запускались |
| Cachix push, pin и remote path-info | passed | passed |

`actionlint` с ShellCheck и синтаксис smoke-script проверены локально.
В ходе CI найдено и исправлено преждевременное обращение теста к Sub-Store:
назначение порта предшествует HTTP listen worker-потока. Теперь проверяется
реальная готовность сервиса с ограниченным ожиданием; ошибки ответа не
игнорируются. Также исправлена проверка placeholder hashes через `if`,
чтобы обнаружение placeholder гарантированно завершало шаг ошибкой.

Все шесть runtime closures опубликованы и закреплены в
https://nixpkgs-pr-build-test.cachix.org:

| System | Пакет | Store path |
| --- | --- | --- |
| x86_64-linux | clash-party | `/nix/store/876clbqfq2nfmkac5s7rfs5s1bxafg7q-clash-party-2.0.4` |
| x86_64-linux | mihomo-alpha | `/nix/store/sys44kd4f3mf4w5rliiknlfipsc0c228-mihomo-alpha-1.19.33-unstable-2026-10-26` |
| x86_64-linux | mihomo-smart | `/nix/store/880bbyxan3c78q539l18hdrbalbi0f2y-mihomo-smart-1.19.9-unstable-2026-10-21` |
| aarch64-linux | clash-party | `/nix/store/h09yyli6c3vm0162hz9xdjab194b379x-clash-party-2.0.4` |
| aarch64-linux | mihomo-alpha | `/nix/store/imsgjf1jn8b9ys43xxnrzaj3an6ljgs6-mihomo-alpha-1.19.33-unstable-2026-10-26` |
| aarch64-linux | mihomo-smart | `/nix/store/i3y2v77al49n3ylx5qzf6dlr1k9mbxm0-mihomo-smart-1.19.9-unstable-2026-10-21` |

Имена pins: `<attribute>-<version>-<system>`, например
`mihomo-smart-1.19.9-unstable-2026-10-21-x86_64-linux`.

Для получения именно проверенной сборки, без локальной компиляции:

```sh
cachix use nixpkgs-pr-build-test
nix build --max-jobs 0 github:vertigo-red/nixpkgs/2f81bb8bb21e3b4905ee0882462fc61f7d597ee1#clash-party
./result/bin/clash-party
```

Для отдельных ядер замените `#clash-party` на `#mihomo-alpha` или
`#mihomo-smart`. Для TUN также включите NixOS-модуль из этой же ревизии и
добавьте пользователя в группу, как в примере выше.

Workflow закрепляет точный source commit, использует native x86_64 и ARM
runners, включает Nix sandbox и публикует runtime closures только после
успешных проверок соответствующего job. Он также проверяет, что прежние
кэшированные Clash Verge и MetaCubeXD всё ещё доступны.

В CI предусмотрены сборка трёх пакетов, их unit checks, запуск Electron с UI,
preload IPC и Sub-Store API/frontend, переключение stable/Alpha/Smart ядер.
На x86_64 запускаются три NixOS VM tests: authenticated HTTP/SOCKS и неверные
пароли для обоих новых ядер, доступ разрешённой/посторонней группы и создание
реального TUN каждым из трёх ядер с сохранением UID обычного пользователя.
ARM VM tests в этом workflow не заявлены.

`nixpkgs-review` не запускался; это поле в PR template должно остаться пустым.
Прямые сборки затронутых пакетов и их integration tests описаны отдельно.

### Вопрос перед отправкой в upstream

В Nixpkgs ранее удалили `mihomo-party`:
https://github.com/NixOS/nixpkgs/pull/435188.
В текущем upstream alias по-прежнему сообщает об удалении из-за нарушения
лицензии. У нынешних source snapshots указана GPL-3.0; сборка из исходников
показывает происхождение используемых ядер, но сама по себе не доказывает
урегулирование прежних претензий и не отменяет решение upstream.
PR должен явно раскрывать это как возвращение приложения и просить ревью
приемлемости повторного включения. Alias в этой ветке не меняется.

В README обоих выбранных ядер после GPL-3.0 также есть условие об использовании
слова `mihomo` в именах неаффилированных downstream-проектов:
[Alpha](https://github.com/MetaCubeX/mihomo/blob/b6a15182c2870f42eb04df7b763171fd3e2f1da4/README.md#license),
[Smart](https://github.com/vernesong/mihomo/blob/462455136157a760937c666bba71afe33b1a809e/README.md#license).
Новый GUI называется Clash Party. Применимость этого условия к Smart fork и
именам вариантов пакета также следует явно включить в upstream review;
проверка одного файла LICENSE не отвечает на этот вопрос.

Перед отправкой нужен самостоятельный человеческий review и принятие
ответственности автором согласно Automation/AI policy. AI disclosure необходим
также в тексте PR и последующих содержательных комментариях.

## metacubexd-desktop-packaging

Проверен HEAD `1f6e0dcbd74de0b37871f9c88e317a3934765940`.
Ветка не изменялась в рамках этой проверки.

- Отдельный `maintainers: add vertigo-red` предшествует пакету.
  Заголовок init корректен, `Assisted-by` есть во всех коммитах.
- Новый пакет, новый модуль, тест и release note объединены в
  `3133632b48ba958aaefd8e394f9ad6fb1aa6be93`.
  Для последовательного применения commit conventions следует выделить
  `nixos/metacubexd-desktop: init module` в отдельный логический коммит.
- Начальный commit содержит `pnpmDeps.hash = lib.fakeHash`, исправленный в
  `c53af52de31691b3f9ffb81e778fb5bd4d0cb19d`. На конечном HEAD hash настоящий.
  Dependency fixes и необходимые runtime fixes нужно объединить с init,
  чтобы не оставлять заведомо несобираемый промежуточный пакет в PR.
- У нового модуля есть `meta.maintainers`, но нет `meta.doc` и подключённой
  документации модуля, которую рекомендует checklist новых модулей.
- Release note и `passthru.tests.nixos` присутствуют. Helper использует
  отдельного обычного пользователя, runtime token вне store, capabilities
  и явную загрузку TUN. Есть GUI/backend smoke и реальный NixOS TUN test.
- Последний успешный CI:
  https://github.com/vertigo-red/nixpkgs/actions/runs/39560253447.
  Он закреплён на `c53af52...`, а не на merge-HEAD `1f6e0dc...`.
  После подготовки окончательной истории нужно перепривязать CI и повторить
  проверки именно итоговой ревизии.
- Перед PR рекомендуется rebase на актуальную upstream-базу и удаление
  вспомогательного merge-коммита. Сам факт наличия merge-коммита не назван
  безусловным нарушением в CONTRIBUTING.md.

Вывод: конечный рецепт имеет успешную проверенную сборку, но история и
документация нового модуля ещё требуют подготовки перед upstream PR.

## clash-verge-rev-update

Проверен HEAD `8f8cba55d7c78cd42c1b0acc9f3f4f1b1f04b067`.
Ветка не изменялась в рамках этой проверки.

- `clash-verge-rev: 2.5.2 -> 2.5.8` соответствует package commit convention.
  Есть release links, сохранено указание соавтора HHR2020 и добавлен
  `Assisted-by`. AI disclosure имеется также у merge-коммита.
- Связанные изменения версии сервиса, unit name, package layout и модуля
  обеспечивают совместимость обновлённого клиента и могут составлять одну
  логическую единицу с обновлением. Оснований объявлять их обязательное
  разделение правилом не найдено.
- Breaking rename `clash-verge.service` → `clash-verge-service.service`
  отражён в release notes. Источники и dependency hashes закреплены.
- Успешная сборка/Cachix:
  https://github.com/vertigo-red/nixpkgs/actions/runs/39580184421.
  Workflow разрешает source branch в SHA перед сборкой, но не включает
  полноценный runtime test GUI + privileged service + TUN. Для изменения
  протокола/сервиса это остаётся существенным пробелом проверки перед PR.
- Рекомендуется rebase на текущую upstream-базу и очистка merge-коммита;
  это рекомендация для понятного review, а не отдельный формальный запрет.

Вывод: явных нарушений формата commit messages или AI trailers не найдено.
Перед upstream PR следует подтвердить runtime-интеграцию сервиса и TUN на
итоговой базе; наличие собранного пакета само по себе этого не проверяет.

## Документы

- https://github.com/NixOS/nixpkgs/blob/d6471495b69e4c0054040c1e7d84258710293542/CONTRIBUTING.md
- https://github.com/NixOS/nixpkgs/blob/d6471495b69e4c0054040c1e7d84258710293542/pkgs/README.md
- https://github.com/NixOS/nixpkgs/blob/d6471495b69e4c0054040c1e7d84258710293542/nixos/README.md
- https://github.com/NixOS/nixpkgs/blob/d6471495b69e4c0054040c1e7d84258710293542/maintainers/README.md
- https://github.com/NixOS/nixpkgs/blob/d6471495b69e4c0054040c1e7d84258710293542/.github/PULL_REQUEST_TEMPLATE.md
