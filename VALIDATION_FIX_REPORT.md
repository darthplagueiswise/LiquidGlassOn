# WATweaks dev2 ZIP revisão

Origem: `/mnt/data/WATweaksdev2(1).zip`

## Revisão realizada

Arquivos revisados na árvore extraída:

- `Makefile`
- `control`
- `.github/workflows/build.yml`
- `src/Tweak.x`
- `src/WAGramPrefix.h`
- `src/WAPrefix.h`
- `src/WAUtils.h`
- `src/WAUtils.m`
- `src/WAKeychainPatch.h`
- `src/WAKeychainPatch.xm`
- `src/WAEmployeeDogfoodHooks.h`
- `src/WALiquidGlassHooks.h`
- `src/Hooks/WAABPropsObserver.xm`
- `src/Hooks/WAEmployeeDogfoodHooks.xm`
- `src/Hooks/WALiquidGlassHooks.xm`
- `src/Menu/WAGramMenuVC.h`
- `src/Menu/WAGramMenuVC.m`
- `modules/SideloadPatch/WASideloadPatch.xm`
- `modules/fishhook/fishhook.c`
- `modules/fishhook/fishhook.h`
- scripts, workflow, resources e docs.

## Correções aplicadas

### Makefile

- Removido `-include src/WAGramPrefix.h` de `CFLAGS` para impedir que `fishhook.c` importe Foundation/UIKit.
- Mantido import explícito do prefix nos arquivos Objective-C/Logos que precisam dele.
- Corrigido bloco `ifdef SIDESTORE` sem indentação indevida na atribuição de variável.
- Fixado target mínimo como `iphone:clang:16.2:15.0`.
- Adicionado `$(TWEAK_NAME)_LIBRARIES = substrate`.

### Prefix/aliases

- `src/WAGramPrefix.h` agora contém todos os aliases usados pela árvore:
  - `kWAGRKeychain`
  - `kWAGRKeychainObserver`
  - `kWAGREmployeeMaster`
  - `kWAGRABPropsObserver`
  - `kWAGRLiquidGlassMaster`
  - `kWAGRLiquidGlassUserDefaults`
  - `kWAGRLiquidGlassMethodHooks`
  - `kWAGRDebugMode`
  - todos `kWAGRLG_*`
  - `WAGRWAABKeyRuntimeValue`

### WAABPropsObserver

- Removidos helpers duplicados `WAGRWAABKey*` do `.xm`; agora usa o prefix único.
- Exportados com linkage C:
  - `WAGRWAABEnsureHooksInstalled`
  - `WAGRWAABDiagnosticText`
  - `WAGRABObsLog`
  - `WAGRABObsClear`
- String override tri-state alinhado:
  - mode 0 = system
  - mode 1 = empty/OFF
  - mode 2 = `enabled` ou string customizada.

### Keychain

- Corrigido retorno de `CFBridgingRetain(q)`:
  - `return (CFDictionaryRef)CFBridgingRetain(q);`
- Removido uso de `__builtin_return_address`, `Dl_info` e `dladdr`.
- Exportados com linkage C:
  - `WAInstallKeychainPatchIfNeeded`
  - `WAKeychainAccessGroupDiagnostic`

### Dogfood / Employee

- Removido `_wagrDFOnce` não usado.
- Corrigido `extern "C" extern "C"` duplicado.
- Exportados com linkage C:
  - `WAGRDogfoodEnsureHooksInstalled`
  - `WAGRDogfoodDiagnosticText`

### LiquidGlass

- `WAGRLGPrefsDidChange` exportado com linkage C.
- Startup continua inert quando master está OFF.
- `WAGRLGPrefsDidChange` aplica defaults e só instala hooks quando master estiver ON.

### Menu

- Corrigido macro `SW(key, ...)`, que quebrava o selector Objective-C `key:`.
- Agora é `SW(prefKey, ...)`.
- Corrigido import relativo do prefix no submenu: `../WAGramPrefix.h`.
- Corrigido `extern "C"` em `WAGramMenuVC.h` para envolver apenas funções C, não `@interface`.

### Tweak.x

- Importa `WAGramPrefix.h` explicitamente.
- Defaults registrados incluem keychain observer e opções LG userdefaults/method hooks.

## Validações realizadas no container

- ZIP original extraído sem erro.
- JSONs `.json.gz` em `resources/` descompactam e fazem parse JSON.
- Verificação sintática com clang/mock headers nos arquivos:
  - `src/Hooks/WAABPropsObserver.xm`
  - `src/Hooks/WAEmployeeDogfoodHooks.xm`
  - `src/Hooks/WALiquidGlassHooks.xm`
  - `src/WAKeychainPatch.xm`
  - `src/WAUtils.m`
  - `src/Menu/WAGramMenuVC.m`
  - `src/Tweak.x` convertido de `%ctor` para constructor só para syntax-check.
- Checks estáticos sem ocorrências de:
  - `__builtin_return_address`
  - `Dl_info`
  - `#define SW(key`
  - `extern "C" extern`
  - `-include src/WAGramPrefix.h`
  - `return CFBridgingRetain(q);`

## Limitação

Não foi executado `make package` real porque o container não possui o mesmo Theos/iPhoneOS SDK da GitHub Action. O pacote foi validado estaticamente para os erros de compilação que estavam aparecendo e para consistência de símbolos/imports.
