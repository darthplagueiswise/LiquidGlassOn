# WAGram / LiquidGlassOn coding guideline

Este guia existe para evitar os erros recorrentes que quebraram a `dev5`: imports faltando, interfaces duplicadas, class extension sem classe primária, `extern "C"` em arquivo Objective-C, hooks pesados no launch e whitespace que falha no `git diff --check`.

## 1. Regra de ouro

A UI só pode escrever aquilo que os hooks leem. Um toggle visual sem hook real é bug. Um hook lendo uma chave diferente da UI também é bug.

Antes de adicionar qualquer toggle, responda:

```text
Qual chave ele grava?
Qual hook lê essa chave?
Quando esse hook é instalado?
Se a chave estiver ausente, o hook chama o original?
Como resetar essa chave?
```

## 2. Arquivos `.x`, `.m`, `.xm` e `.mm`

`Tweak.x` vira Objective-C `.m` no build do Theos. Portanto:

```objc
// errado em .x/.m
extern "C" void Foo(void);

// correto em .x/.m
extern void Foo(void);
```

Use `extern "C"` apenas em `.xm` ou `.mm`, ou em header compartilhado com guarda:

```objc
#ifdef __cplusplus
extern "C" {
#endif

void Foo(void);

#ifdef __cplusplus
}
#endif
```

## 3. Interfaces Objective-C

Se existir:

```objc
@interface MinhaClasse ()
@end

@implementation MinhaClasse
@end
```

precisa existir antes:

```objc
@interface MinhaClasse : UITableViewController
@end
```

Sem isso, o compilador trata a classe como root class e aparecem erros como:

```text
class extension has no primary class
cannot use 'super' because it is a root class
property 'tableView' not found
```

## 4. Dono único de cada classe

Não implemente a mesma classe global em dois arquivos. Exemplo proibido:

```text
WAGramMenuVC.m implementa WAGRWAABTriStateBrowserVC
WAGramWAABRuntimeCategoriesVC.m também implementa WAGRWAABTriStateBrowserVC
```

Se precisar de uma cópia local, renomeie:

```text
WAGRWAABRuntimeTriStateBrowserVC
```

## 5. Headers compatíveis

Se uma classe já está declarada em `WAGramMenuVC.h`, outro header não deve redefinir a interface.

Header compatível correto:

```objc
#pragma once
#import "WAGramMenuVC.h"
```

Header compatível errado:

```objc
@interface WAGRRuntimeMethodBrowserVC : UITableViewController
@end
```

## 6. Startup seguro

O WhatsApp precisa abrir antes de qualquer hook pesado. Por padrão:

```text
wagr_startup_hooks_enabled = NO
```

Estes módulos não podem instalar hooks amplos no constructor quando essa chave está OFF:

```text
WAABPropsObserver.xm
WAGramBundleHooks.xm
WAEmployeeDogfoodHooks.xm
WADebugBuildHooks.xm via Tweak.x
```

O padrão correto é:

```objc
if (![[NSUserDefaults standardUserDefaults] boolForKey:@"wagr_startup_hooks_enabled"]) {
    NSLog(@"[WAGram] inert startup; hooks install only from menu/toggle");
    return;
}
```

Depois que o usuário liga um toggle no menu, a UI pode chamar:

```objc
WAGRWAABEnsureHooksInstalled();
WAGRBundleEnsureHooksInstalled();
WAGRDogfoodEnsureHooksInstalled();
WAGRNativeSurfaceEnsureHooksInstalled();
```

## 7. Persistência WAAB

Contrato atual:

```text
wagr.waab.<flag> = "on"   -> força YES
wagr.waab.<flag> = "off"  -> força NO
chave ausente              -> original/sistema
```

Não use `.mode` misturado com `on/off`. Não use `setInteger:` para WAAB nesta árvore. Se migrar para boolean real no futuro, migre UI, hooks, reset e diagnósticos juntos.

## 8. Chamando o original

Todo hook precisa chamar o original quando não há override. Exemplo:

```objc
if ([stored isEqualToString:@"on"]) return YES;
if ([stored isEqualToString:@"off"]) return NO;
return orig ? orig(self, _cmd) : NO;
```

Não retorne `YES` por padrão em hook genérico. Isso abre gates erradas e pode crashar telas internas.

## 9. Runtime browser

Runtime browser só escaneia quando a tela abre. Nunca faça scan global no launch por causa dele.

NativeSurface deve usar registry exato:

```text
classe + selector + instance/class method
```

## 10. Reset

Todo menu categorizado precisa resetar apenas as próprias chaves. Reset global deve ficar em tela/ação explícita de sistema.

Após reset:

```objc
[ud synchronize];
WAGRWAABEnsureHooksInstalled();
WAGRBundleEnsureHooksInstalled();
```

Se for LiquidGlass, também:

```objc
WAGRLGPrefsDidChange();
```

## 11. Whitespace e EOF

Antes de zipar ou commitar:

```sh
git diff --check
```

Erros proibidos:

```text
trailing whitespace
new blank line at EOF
```

Remova espaços no fim das linhas e deixe exatamente uma quebra de linha no fim do arquivo, sem linhas vazias extras.

## 12. Validação obrigatória

Sempre rode:

```sh
python3 scripts/wagr_validate_sources.py
git diff --check
```

O validador precisa checar:

```text
extern "C" em .m/.x
imports faltando
interfaces primárias obrigatórias
headers compatíveis sem redefinir interface
classe duplicada entre arquivos
safe-startup guards
unconditional WAGRDebugBuildEnsureHooksInstalled()
trailing whitespace / blank line at EOF
```

## 13. Checklist antes de escrever um arquivo novo

Use este checklist:

```text
[ ] O arquivo tem a extensão certa para o tipo de código?
[ ] Se usa class extension, existe primary interface?
[ ] Não duplica uma classe já implementada em outro arquivo?
[ ] Imports existem no zip/repo?
[ ] Não usa extern "C" em .m/.x?
[ ] Não instala scan/hook pesado no launch?
[ ] Toggle escreve a mesma chave que o hook lê?
[ ] Ausência da chave chama o original?
[ ] Reset remove as chaves certas?
[ ] git diff --check passa?
[ ] scripts/wagr_validate_sources.py passa?
```
