# WAGram Coding Guidelines — NSUserDefaults, Hooks and Crash-Safe UI

## Primeira regra

O app precisa abrir e o menu precisa ficar utilizável antes de qualquer hook pesado ser instalado. Toggle que crasha antes do usuário conseguir resetar é regressão crítica.

## NSUserDefaults reset

O reset de emergência precisa limpar o domínio completo do `NSUserDefaults`, não só prefixos `wagr.*`, `aura_*` ou `ios_*`. Builds antigas podem ter gravado os mesmos conceitos com tipos diferentes: string `on/off`, boolean `1/0`, `.mode`, chaves nativas `wa_*`, `aura_*`, `ios_*` ou nomes sem prefixo.

Use domínio completo:

```objc
NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
if (bundleID.length) [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleID];
for (NSString *key in [[NSUserDefaults standardUserDefaults] dictionaryRepresentation].allKeys) {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
}
[[NSUserDefaults standardUserDefaults] synchronize];
CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
```

Não chame instaladores de hook durante reset. Limpe, sincronize e feche o app.

## Toggle seguro

Por padrão, toggle deve apenas persistir a preferência. Não chame `WAGRWAABEnsureHooksInstalled`, `WAGRBundleEnsureHooksInstalled`, `WAGRDogfoodEnsureHooksInstalled` ou `WAGRNativeSurfaceEnsureHooksInstalled` diretamente no evento do switch, porque isso pode rodar scan/hook enquanto o WhatsApp ainda não está em estado seguro.

Use chave explícita para testes avançados:

```objc
wagr_immediate_apply_hooks_enabled = YES
```

Default deve ser OFF.

## Hook installers

Instaladores pesados devem ser chamados por fluxo explícito, diagnóstico, relaunch controlado ou constructor seguro quando os defaults já estão limpos e compatíveis. Nunca esconda scan pesado dentro de um setter visual.

## Storage WAAB v10/v191

```text
wagr.waab.<flag> = "on"   -> force YES
wagr.waab.<flag> = "off"  -> force NO
absent                    -> system/original
```

Não misture `.mode`, boolean e string no mesmo leitor/escritor.

## Build hygiene

Sempre rodar:

```sh
python3 scripts/wagr_validate_sources.py
git diff --check
```

`git diff --check` precisa passar sem trailing whitespace e sem blank line extra no EOF.
