# WATweaks refactor aplicado

Aplicado em cima do ZIP enviado.

## Principais mudanças

- `TWEAK_NAME` renomeado de `LiquidGlassOn` para `WATweaks`.
- `LiquidGlassOn.plist` renomeado para `WATweaks.plist`, mantendo o filtro `net.whatsapp.WhatsApp` para evitar erro de filter plist no Theos.
- `control` atualizado para `Package: com.darthplagueiswise.watweaks` e `Name: WATweaks`.
- `src/Tweak.x` reescrito a partir do overwrite enviado:
  - mantém o long-press via `UITableView -didMoveToWindow`;
  - chama `WAGRMaybeAttachWATweaksFooter(tv)` quando a tabela de Settings aparece;
  - remove ownership direto de `isDebugMenuAllowed`, delegando para o hook dedicado.
- Adicionado `src/Hooks/WAGRNativeDevMenuHooks.xm`:
  - dono único de `isDebugMenuAllowed` e `isDebugMenuShortcutEnabled`;
  - alvo primário `_TtC15WADebugMenuMain17DebugMenuProvider`;
  - retry em 0.2s / 1.0s / 3.0s.
- Adicionado `src/Hooks/WAGRWATweaksSettingsRow.xm`:
  - injeta a linha visual “WATweaks” como `tableFooterView` na tela nativa de Settings;
  - não mexe no data source do WhatsApp;
  - apresenta `WAGRSurfaceListVC` ao toque.
- `src/Hooks/WAGREmployeeHooks.xm` substituído pelo overwrite enviado:
  - remove broad scan;
  - usa candidato determinístico, com `WAServerProperties` como dono confirmado de `isInternalUser`;
  - mantém trampolins forward-compatible para os outros gates.
- `src/Hooks/WAGRContextHooks.xm` reduzido ao único hook confirmado, `WAContextMain isVerifiedChannelFeatureFlagEnabled`.
- Removidos os stubs sem consumidor:
  - `src/WAEmployeeDogfoodHooks.h`
  - `src/Hooks/WAEmployeeDogfoodHooks.xm`
- `QuartzCore` adicionado ao Makefile porque a nova linha nativa usa `CALayer.cornerCurve` / `kCACornerCurveContinuous`.
- Corrigido cast em `WAABPropsObserver.xm` para passar na validação local do projeto.

## Validação executada

```sh
python3 scripts/wagr_validate_sources.py
```

Resultado:

```text
OK: WAGram router Ryuk-style bundle validation passed
```

## Observação

Não rodei build Theos real aqui porque o ambiente do sandbox não tem Theos/iPhoneOS SDK instalado. A validação local do projeto passou e o layout do Theos foi ajustado para o novo `TWEAK_NAME` com `WATweaks.plist` correspondente.
