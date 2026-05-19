# WAGram v10 dev5 — checklist completo de revisão

## Resumo do problema corrigido

O erro final vinha de uma correção anterior incorreta: foi criado um método `confirmNuclearReset` em category, enquanto o selector também tinha sido declarado na interface primária. Com `-Werror`, isso vira `-Wobjc-protocol-method-implementation`; além disso, declarar o método sem implementá-lo dentro da primary implementation gerava `-Wincomplete-implementation`.

Correção aplicada: `confirmNuclearReset` agora é método privado declarado na class extension de `WAGRABFlagBrowserVC` e implementado dentro do bloco `@implementation WAGRABFlagBrowserVC`. Não há arquivo category separado para esse selector.

## Validações executadas no zip extraído

```text
python3 scripts/wagr_validate_sources.py
Resultado: OK: WAGram source validation passed

git diff --check
Resultado: sem erros

EOF/CRLF validator
Resultado: OK eof/crlf validation passed
```

Observação honesta: não rodei o build Theos/macOS real aqui porque este sandbox não tem toolchain Theos + iPhoneOS SDK do GitHub Actions. A revisão cobre os erros estáticos recorrentes que derrubaram a build: interface/implementation, category warning, imports, `extern "C"`, duplicate class, startup guards e whitespace.

## Arquivos alterados nesta revisão

| Arquivo | Ação |
|---|---|
| `src/Menu/WAGramMenuVC.m` | Corrigido `confirmNuclearReset` dentro da primary implementation de `WAGRABFlagBrowserVC`; manteve o reset total sem prefix filter; não usa category. |
| `scripts/wagr_validate_sources.py` | Validator ampliado para detectar category implementando método já declarado na interface primária e para garantir o contrato de `WAGRABFlagBrowserVC confirmNuclearReset`. |
| `WAGRAM_CODING_GUIDELINES.md` | Guidelines reescritas com regras de entrega sem half-patch, Objective-C selectors, class extensions, startup seguro, reset total e validação obrigatória. |
| `CLAUDE.md` | Regras diretas para Claude Code: não entregar zip + script remendando, não usar category para método declarado, startup inert, toggle seguro e validação antes de devolver. |

## Checklist arquivo por arquivo

| Arquivo | SHA256 curto | Revisão |
|---|---:|---|
| `.clangd` | `8d1339072faa` | configuração de tooling; mantida; sem impacto runtime. |
| `.github/workflows/build-enableliquidglass.yml` | `d92828eb12c9` | workflow dev5; revisado para manter build Theos/GitHub Actions. |
| `.gitignore` | `4d187b645ef4` | higiene git; mantido. |
| `.gitmodules` | `5790f0d2fc48` | submódulos; mantido. |
| `.vscode/settings.json` | `97ffbda1c47d` | configuração editor; mantida. |
| `.vscode/snippets.code-snippets` | `4bb9f1b53e94` | snippets editor; mantido. |
| `.vscode/tasks.json` | `ded92bb9e215` | tasks editor; mantidas. |
| `CLAUDE.md` | `5defa37e4765` | atualizado/revisado com regra de não entregar patch pela metade, selector em primary implementation, startup seguro e validação obrigatória. |
| `LiquidGlassOn.plist` | `e9f7b3adb367` | filter plist do tweak; mantido. |
| `MERGE_NOTES_V6_PLUS_FINAL.md` | `fdca262bef22` | notas históricas; mantidas. |
| `Makefile` | `41666c33b7e1` | descoberta de fontes via find; validado que novos .m seriam compilados automaticamente; nenhum arquivo extra de category foi adicionado. |
| `VALIDATION_FIX_REPORT.md` | `acaa557140bc` | relatório antigo; mantido. |
| `WAGRAM_CODING_GUIDELINES.md` | `1bae2e1f3fc6` | atualizado com guidelines robustas: selector/interface, categories, reset total, startup inert, toggle seguro, validação. |
| `WAGram_v10_nuclear_reset_review.md` | `12ae5c76d226` | relatório anterior; mantido como histórico. |
| `build-dev.sh` | `c47f5c1c112a` | script build; mantido. |
| `build-fast.sh` | `0aeac97ceaed` | script build rápido; mantido. |
| `build.sh` | `3ceed00e4e26` | script build; mantido. |
| `control` | `094172509bf1` | controle Debian; mantido. |
| `docs/SETTINGS_HIDDEN_ROWS.md` | `66a145a5149d` | documentação; mantida. |
| `docs/waab_selected_categories_getter_validation_report.md` | `141bbc03e922` | documentação de catálogo; mantida. |
| `modules/SideloadPatch/WASideloadPatch.xm` | `e4d8819b402d` | módulo sideload condicional; mantido. |
| `modules/fishhook/fishhook.c` | `48f51e1a36d9` | dependência fishhook; mantida. |
| `modules/fishhook/fishhook.h` | `ae4a6dd3598b` | dependência fishhook; mantida. |
| `push_wagr_dev5_nuclear_reset_zip.sh` | `a6b55c284496` | script histórico de upload; mantido, mas entrega final recomenda comando direto simples. |
| `resources/waab_selected_categories_bool_only_catalog.json.gz` | `e57e420916f2` | recurso WAAB compactado; mantido. |
| `resources/waab_selected_categories_getter_validated_catalog.json.gz` | `1a60a2c79879` | recurso WAAB compactado validado; mantido. |
| `scripts/sync-dev2-build-assets.sh` | `222c5e7e8b43` | script de sync; mantido. |
| `scripts/wagr_validate_sources.py` | `01f57f2e6ca8` | atualizado para capturar category implementando método declarado pela interface primária e WAGRAB confirmNuclearReset sem implementação primária. |
| `src/Hooks/WAABPropsObserver.xm` | `6127bde5348d` | revisado: mantém safe-startup guard; não reinstala hooks pesados no launch por padrão. |
| `src/Hooks/WAAuraHooks.xm` | `8ad192770eca` | revisado estruturalmente; mantido. |
| `src/Hooks/WADebugBuildHooks.xm` | `92f7b121d6ce` | revisado estruturalmente; broad scan condicionado via Tweak.x/defaults. |
| `src/Hooks/WAEmployeeDogfoodHooks.xm` | `8e20076ad5ca` | revisado: mantém safe-startup guard; retries só quando habilitado/acionado. |
| `src/Hooks/WAGramBundleHooks.xm` | `424124d0cf80` | revisado: mantém safe-startup guard; bundle hooks não entram no startup por padrão. |
| `src/Hooks/WAGramNativeSurfaceHooks.xm` | `75bf58a124f7` | revisado estruturalmente; NativeSurface deve ser registry/on-demand. |
| `src/Hooks/WALiquidGlassHooks.xm` | `07c505f89faa` | revisado estruturalmente; Logos hooks mantidos. |
| `src/Menu/WAGRRuntimeMethodBrowserVC.h` | `a77d77061174` | compat header revisado; não redefine interface duplicada. |
| `src/Menu/WAGRRuntimeMethodBrowserVC.m` | `3d09754abb1f` | runtime browser revisado estruturalmente; sem startup scan global. |
| `src/Menu/WAGramMenuVC.h` | `24a27d812bea` | revisado; primary interfaces centralizadas; não declara confirmNuclearReset em WAGRAB para evitar category warning. |
| `src/Menu/WAGramMenuVC.m` | `f374bfd4fd5a` | corrigido: WAGRABFlagBrowserVC agora declara e implementa confirmNuclearReset dentro da primary implementation; remove dependência de category e resolve -Wincomplete-implementation. |
| `src/Menu/WAGramWAABRuntimeCategoriesVC.h` | `a77d77061174` | compat header revisado; não redefine interface duplicada. |
| `src/Menu/WAGramWAABRuntimeCategoriesVC.m` | `e1abc7e2c2f1` | revisado: usa WAGRWAABRuntimeTriStateBrowserVC local para não duplicar WAGRWAABTriStateBrowserVC. |
| `src/Tweak.x` | `ae2c0df3f8e1` | revisado: sem extern C bruto em .x e DebugBuild não deve rodar broad scan incondicional. |
| `src/WAEmployeeDogfoodHooks.h` | `0c7408c25d60` | header; mantido. |
| `src/WAGramPrefix.h` | `ef193d781f27` | helpers globais; revisado semanticamente. |
| `src/WAKeychainPatch.h` | `38b6f6aef3cd` | header keychain; mantido. |
| `src/WAKeychainPatch.xm` | `1ef53d209687` | fishhook SecItem; mantido. |
| `src/WALiquidGlassHooks.h` | `35c86d88d973` | header LiquidGlass; mantido. |
| `src/WAPrefix.h` | `5071786365ad` | prefix/base prefs; mantido. |
| `src/WAUtils.h` | `2566a6091f01` | utils header; mantido. |
| `src/WAUtils.m` | `04e96bec37c4` | utils impl; mantido. |

## Comando iSH recomendado

Este comando substitui o repo pela versão completa revisada, valida e commita. Ele não edita código depois da extração; o zip já vem pronto.

```sh
cd /root/LiquidGlassOn && \
git fetch origin --prune && \
git checkout dev5 && \
git reset --hard origin/dev5 && \
rm -rf /tmp/wagr_full_review && \
mkdir -p /tmp/wagr_full_review && \
unzip -q /root/LiquidGlassOn-wagr-v10-dev5-full-reviewed.zip -d /tmp/wagr_full_review && \
SRC="$(find /tmp/wagr_full_review -maxdepth 3 -type f -name Makefile -exec dirname {} \; | head -n 1)" && \
[ -n "$SRC" ] || { echo "ERRO: Makefile não encontrado no zip"; exit 1; } && \
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} + && \
cp -a "$SRC"/. . && \
python3 scripts/wagr_validate_sources.py && \
git diff --check && \
git status --short && \
git add -A && \
git commit -m "Import WAGram v10 dev5 full reviewed build" && \
git push origin dev5
```
