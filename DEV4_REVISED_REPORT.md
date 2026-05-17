# LiquidGlassOn dev4 revised merge report

Base analisada: `LiquidGlassOn-v7.zip`.

Objetivo aplicado: manter a UI estilo RyukGram/WAGram do v7 e corrigir os pontos de runtime que impediam retry real ou override OFF explícito.

## Alterações principais

1. `src/Menu/WAGramMenuVC.m`
   - `FlagSet(flag, NO)` agora grava `wagr.waab.<flag> = "off"`, em vez de remover a chave.
   - O master toggle dos bundles agora grava `"off"` nas flags positivas quando desligado.
   - Killswitches continuam seguros: ao ligar bundle, killswitch vai para `"off"`; ao desligar bundle, killswitch volta para sistema/removido.
   - O browser/lista agora distingue `ON`, `OFF override` e `system`.
   - Removido `static const char kMasterKey = 0`, que o validador marcava como resíduo inválido.

2. `src/Hooks/WAGRAuraGatingHooks.xm`
   - `gAuraGatingHooksInstalled` não é mais marcado antes do scan.
   - A flag só vira instalada após achar pelo menos um hook real de Aura gating ou row hook.
   - O dicionário de IMPs originais é preservado entre retries.

3. `src/Hooks/WAGRContextHooks.xm`
   - `gContextHooksInstalled` não é mais marcado antes do scan.
   - O retry continua até os hooks centrais `isDebugBuild` e `isDebugMenuAllowed` existirem.

4. `src/Hooks/WAEmployeeDogfoodHooks.xm`
   - Employee/Dogfood agora só considera instalado quando os quatro selectors centrais foram encontrados:
     - `isMetaEmployeeOrInternalTester`
     - `is_meta_employee_or_internal_tester`
     - `isInternalUser`
     - `graphQLEmployeeC1Disabled`
   - Se vier parcial, os retries continuam sem perder os originais já capturados.

5. `src/Hooks/WAABPropsObserver.xm`
   - WAAB não marca `installed=YES` se `WAABProperties` ainda não carregou ou se nenhum hook real foi instalado.

6. `.github/workflows/build-enableliquidglass.yml`
   - Workflow apontado para branch `dev4`.

## Validação local feita

- Validação do script: OK
  - sem `[[self.navigationController]`
  - sem `static const char kMasterKey = 0`
  - sem regex quebrada de `hasPrefix:@"wagr." ||`
  - `FlagSet` grava `"off"`
- `git diff --check`: clean
- Gross brace scan: OK

Não rodei `make package`, porque o sandbox não tem Theos/iPhoneOS SDK/Substrate.
Resultado: `static checks OK`.
