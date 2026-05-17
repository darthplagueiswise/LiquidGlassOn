# AGENTS.md — LiquidGlassOn / WAGram

Guia obrigatório para ChatGPT, Codex, Claude Code e qualquer agente que edite este repositório.

Objetivo: reduzir erro de build, preservar a arquitetura funcional de override/persistência e impedir mudanças grandes sem validação.

---

## 1. Regra principal

Antes de editar:

1. Leia este arquivo.
2. Leia os arquivos reais envolvidos.
3. Faça a menor alteração possível.
4. Não invente outro padrão se já existe um funcionando.
5. Não declare “build OK” sem rodar `make package` ou sem ver o GitHub Actions passar.

Quando só rodar validação estática, diga: `static checks OK`.

---

## 2. Ambiente de build

Este projeto é um tweak Theos para WhatsApp.

Makefile esperado:

```make
TARGET := iphone:clang:16.2:15.0
INSTALL_TARGET_PROCESSES = WhatsApp
ARCHS = arm64
```

A build usa clang/Theos e trata warnings como erro em vários casos. Portanto:

- variável unused quebra build;
- função sem prototype quebra build;
- string Objective-C quebrada quebra build;
- `%orig` fora de hook quebra preprocessamento Logos;
- classe implementada sem `@interface` primária quebra build.

---

## 3. Branches e base

Não use branch base por chute.

Regras atuais:

- `dev` deve permanecer no commit funcional da run #179:
  `d4ae04bfe948e08167bda636e31715e57198a6a1`
- `dev3` é a branch de trabalho para v7 fixed.
- Não criar `dev3` a partir de `origin/dev` se o usuário não pedir.
- Ao importar zip, resetar primeiro para a base pedida, depois copiar o zip.

Antes de push:

```sh
git status --short
git log --oneline -1
git diff --check
```

---

## 4. Arquivos principais

Não duplicar implementação de classe.

Arquivos principais:

```text
Makefile
Tweak.x
src/Menu/WAGramMenuVC.h
src/Menu/WAGramMenuVC.m
src/Menu/WAGRRuntimeBrowserVC.h
src/Menu/WAGRRuntimeBrowserVC.m
src/WAGramUI.h
src/WAGramUI.m
src/Hooks/WAABPropsObserver.xm
src/Hooks/WALiquidGlassHooks.xm
src/Hooks/WAAuraHooks.xm
src/Hooks/WAGRAuraGatingHooks.xm
src/Hooks/WAGRContextHooks.xm
src/Hooks/WAEmployeeDogfoodHooks.xm
src/WAKeychainPatch.xm
```

Proibido criar `WAGramMenuVCFixed.m` para “contornar” erro. Corrija `WAGramMenuVC.m`.

---

## 5. Declarações obrigatórias

Se um `.m` implementa:

```objc
@interface WAGRABFlagBrowserVC ()
```

então o `.h` precisa declarar a classe primária antes:

```objc
@interface WAGRABFlagBrowserVC : UITableViewController <UISearchResultsUpdating>
- (instancetype)initWithTitle:(NSString *)title flags:(NSArray<NSString *> *)flags;
- (void)reload;
- (void)updateTitle;
@end
```

Toda função chamada em outro arquivo precisa ter prototype visível.

Para funções C exportadas em `.xm`:

```objc
#ifdef __cplusplus
extern "C" {
#endif
void WAGRWAABEnsureHooksInstalled(void);
#ifdef __cplusplus
}
#endif
```

Não colocar `extern "C"` cru em arquivo `.x`.

---

## 6. Padrões de persistência

Não mudar namespace sem migração completa.

### WAAB flags

Formato canônico:

```text
wagr.waab.<flag> = "on" | "off" | ausente
```

Sem `.mode`, sem boolean mirror obrigatório, sem formato paralelo.

Significado:

- `"on"` força YES;
- `"off"` força NO;
- ausente volta para sistema/original.

Helpers devem seguir:

```objc
static BOOL FlagOn(NSString *flag) {
    return [[[NSUserDefaults standardUserDefaults] stringForKey:WAGRKey(flag)] isEqualToString:@"on"];
}

static void FlagSet(NSString *flag, BOOL on) {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    if (on) [ud setObject:@"on" forKey:WAGRKey(flag)];
    else    [ud removeObjectForKey:WAGRKey(flag)];
    [ud synchronize];

    WAGRWAABEnsureHooksInstalled();

    if ([flag containsString:@"liquid_glass"]) WAGRLGPrefsDidChange();
    if ([flag hasPrefix:@"aura_"] || [flag containsString:@"benefit"]) WAGRAuraGatingEnsureHooksInstalled();
    if ([flag containsString:@"dogfood"] || [flag containsString:@"internal"] || [flag containsString:@"employee"]) WAGRDogfoodEnsureHooksInstalled();
}
```

### Context/debug gates

Formato:

```text
wagr.context.<key>
```

Usar bool/remover chave:

```objc
static BOOL CtxOn(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

static void CtxSet(NSString *key, BOOL value) {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    if (value) [ud setBool:YES forKey:key];
    else       [ud removeObjectForKey:key];
    [ud synchronize];
}
```

### Kill switches

Não tratar kill switch como feature positiva.

Para flag negativa (`killswitch`, `kill_switch`, `disabled`, `disable`, `block`, `deny`):

- “Allow Feature” deve gravar `"off"`;
- “Block Feature” deve gravar `"on"`;
- remover override deve apagar a chave.

---

## 7. Hooks permitidos e estilo correto

### WAAB

`WAABPropsObserver.xm` é o dono dos hooks WAAB.

Ele pode hookar:

- getters BOOL diretos de `WAABProperties`;
- caminhos centrais tipo `boolForKey:defaultValue:` / `stringForKey:defaultValue:`, quando existirem;
- somente com leitura do formato `wagr.waab.<flag>`.

Não criar uma segunda tabela de hooks WAAB em outro arquivo.

### Logos

Use `%hook` para classes ObjC estáveis e conhecidas.

Exemplo:

```objc
%hook SomeClass
- (BOOL)someFlag {
    NSString *v = [[NSUserDefaults standardUserDefaults] stringForKey:WAGRKey(@"someFlag")];
    if ([v isEqualToString:@"on"]) return YES;
    if ([v isEqualToString:@"off"]) return NO;
    return %orig;
}
%end
```

`%orig` só pode aparecer dentro de método de `%hook`.

### MSHookMessageEx

Use `MSHookMessageEx` para hooks runtime/ObjC quando:

- classe é descoberta por nome;
- precisa preservar IMP original;
- é método ObjC de instância ou classe;
- precisa instalar hook sob demanda.

Padrão:

```objc
static BOOL (*orig_Method)(id self, SEL _cmd);

static BOOL repl_Method(id self, SEL _cmd) {
    NSString *v = [[NSUserDefaults standardUserDefaults] stringForKey:WAGRKey(@"someFlag")];
    if ([v isEqualToString:@"on"]) return YES;
    if ([v isEqualToString:@"off"]) return NO;
    return orig_Method ? orig_Method(self, _cmd) : NO;
}

static void HookMethod(Class cls, SEL sel) {
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    MSHookMessageEx(cls, sel, (IMP)repl_Method, (IMP *)&orig_Method);
}
```

Para class methods:

```objc
Class meta = object_getClass(cls);
MSHookMessageEx(meta, sel, (IMP)repl, (IMP *)&orig);
```

Não usar `MSHookFunction` para método ObjC. Só usar `MSHookFunction` em C functions reais.

### Swift

Não instanciar Swift VC diretamente sem construtor confirmado e dependências conhecidas.

`@try/@catch` não salva crash fatal do Swift.

Para Aura, preferir gates/flags e navegação nativa existente. Não chamar VC Swift “no seco” se precisa contexto.

---

## 8. Runtime browser

Runtime browser deve ser on-demand.

Permitido:

- escanear runtime somente quando o usuário abrir o browser;
- filtrar getters `BOOL`/`bool`/`char` sem argumentos explícitos;
- persistir override exato por class + selector;
- permitir apagar override.

Proibido:

- `objc_getClassList` global no startup;
- scan amplo 1–2 segundos após launch;
- hookar tudo automaticamente;
- forçar métodos com termos perigosos sem aviso.

Termos de alto risco:

```text
nag
numerical
label
settings
setup
assert
failure
crash
fatal
```

Esses termos já causaram crash em Settings via `WANagScreensSetupNumericalLabels`.

Para runtime override, usar o mesmo conceito semântico:

```text
"on" | "off" | ausente
```

E manter registry pequena para reinstalar só hooks persistidos.

---

## 9. Aura / WA Plus

Aura não depende só de WAAB.

Manter:

```text
WAAuraHooks.xm
WAGRAuraGatingHooks.xm
WAAB flags aura_*
benefit getters
context/debug gates quando necessário
```

Regras:

- `aura_subscription_simulation_enabled` é simulação/debug;
- não escrever lógica de pagamento;
- não inventar `hasPaid`;
- killswitch Aura deve ser invertida corretamente;
- não abrir `AppThemesViewController` / `AppIconsViewController` diretamente se crashar por Swift dependencies.

---

## 10. Settings e entrypoint seguro

Não depender só de Settings para abrir a tweak.

Deve existir fallback seguro:

- long press em Chats;
- long press em título/root chat list;
- ou outro entrypoint que não dependa de Settings.

Motivo: overrides errados em Settings podem crashar a tela antes do usuário conseguir remover o override.

---

## 11. UI

Usar `src/WAGramUI.h/m`.

Padrão visual:

- estilo RyukGram/WAGram já existente;
- SF Symbols sóbrios;
- sem emojis no root se já houver ícones;
- contadores `X/Y`;
- labels longas com fonte monospaced 11–12 pt;
- evitar subtítulos poluídos;
- menus por grupos validados.

Menus desejados:

```text
Masters
Feature Bundles
Runtime Browser
Debug Build Gates
Settings Rows
Actions
```

Dentro dos bundles:

```text
Ativar Grupo
Flags Individuais
Diagnóstico
```

---

## 12. Erros de build recorrentes e correções

### unused variable kMasterKey

Erro:

```text
unused variable 'kMasterKey' [-Werror,-Wunused-const-variable]
```

Correção: remover a linha se não é usada.

```objc
static const char kMasterKey = 0;
```

Não desativar warning globalmente.

### navigationController syntax

Errado:

```objc
[[self.navigationController] pushViewController:vc animated:YES];
```

Certo:

```objc
[self.navigationController pushViewController:vc animated:YES];
```

### hasPrefix com ||

Errado:

```objc
[k hasPrefix:@"wagr." || [k hasPrefix:@"aura_"]]
```

Certo:

```objc
[k hasPrefix:@"wagr."] || [k hasPrefix:@"aura_"]
```

### NSString com quebra real

Errado:

```objc
message:@"linha 1

linha 2"
```

Certo:

```objc
message:@"linha 1\n\nlinha 2"
```

### primary class missing

Se o erro for:

```text
class extension has no primary class
cannot find interface declaration
```

adicione o `@interface Classe : SuperClasse` no `.h` ou antes da extensão no `.m`.

---

## 13. Checklist antes de commit

Rodar:

```sh
git diff --check
grep -R '\[\[self\.navigationController\]' -n src && exit 1 || true
grep -R 'hasPrefix:@"wagr\.".*||' -n src && exit 1 || true
grep -R '%orig' -n src | grep -v '%hook' | grep -v '%end' || true
```

Checar unused key constants:

```sh
grep -R 'static const char k.*Key = 0;' -n src/Menu src/Hooks
```

Se a key não aparece em `objc_getAssociatedObject` ou `objc_setAssociatedObject`, remover.

Validação ideal:

```sh
make clean package
```

Se não rodou build, não diga que build passou.

---

## 14. Formato de resposta do agente

Ao terminar, sempre diga:

```text
Branch:
Base:
Arquivos alterados:
Validação feita:
Commit:
Riscos restantes:
```

Se não fez build completa, escreva explicitamente:

```text
Não rodei build completa; rodei apenas checks estáticos.
```

