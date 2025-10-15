# LiquidGlassOn.dylib (WhatsApp)

Este projeto contém um tweak simples para forçar a ativação do recurso
“Liquid Glass” no WhatsApp (normal e Business) sem a necessidade de
jailbreak. A biblioteca dinâmica gerada injeta uma flag nos App
Groups do WhatsApp e swizzle a implementação da classe
`WDSLiquidGlass` para que o método `isEnabled` sempre retorne
`YES`.

## Como compilar (macOS)

É necessário uma máquina macOS com Xcode instalado. O script de build
invoca `clang` via `xcrun` usando o SDK do iPhone para compilar a
biblioteca para arquitetura arm64. Para compilar:

```bash
git clone <seu‑repo> .
bash build.sh
# Saída: LiquidGlassOn.dylib
```

## Como injetar no IPA

1. **Extraia o IPA** do WhatsApp:

   ```bash
   unzip WhatsApp.ipa -d PayloadWAPP
   ```

2. **Copie a dylib** para o bundle do app:

   ```bash
   cp LiquidGlassOn.dylib PayloadWAPP/Payload/WhatsApp.app/Frameworks/
   ```

3. **Adicione o load command** ao executável principal (use
   [`jtool2`](https://github.com/skyline75489/jtool2) ou
   [`insert_dylib`](https://github.com/Tyilo/insert_dylib)):

   *Com `jtool2`:*

   ```bash
   jtool2 -arch arm64 -insert LC_LOAD_DYLIB @rpath/LiquidGlassOn.dylib \
     -output PayloadWAPP/Payload/WhatsApp.app/WhatsApp.patched \
     PayloadWAPP/Payload/WhatsApp.app/WhatsApp
   mv PayloadWAPP/Payload/WhatsApp.app/WhatsApp.patched \
     PayloadWAPP/Payload/WhatsApp.app/WhatsApp
   ```

   *Com `insert_dylib` (alternativa):*

   ```bash
   insert_dylib --weak --overwrite @rpath/LiquidGlassOn.dylib \
     PayloadWAPP/Payload/WhatsApp.app/WhatsApp
   ```

4. **Entitlements:** extraia os entitlements originais e reaplique na
   resignação para preservar, por exemplo, os App Groups:

   ```bash
   ldid -e PayloadWAPP/Payload/WhatsApp.app/WhatsApp > wapp.xml
   # Reassinar (ex.: usando AltStore/Sideloadly preservando entitlements) OU:
   ldid -S wapp.xml PayloadWAPP/Payload/WhatsApp.app/WhatsApp
   ldid -S wapp.xml PayloadWAPP/Payload/WhatsApp.app/Frameworks/LiquidGlassOn.dylib
   ```

5. **Reempacote e instale** o IPA:

   ```bash
   cd PayloadWAPP && zip -9 -r ../WhatsApp_patched.ipa Payload && cd ..
   # Em seguida instale o IPA assinado usando AltStore/Sideloadly
   ```

> **Dica:** certifique‑se de que a resignação preserve
> `com.apple.security.application-groups`; caso contrário, o seed de
> `NSUserDefaults(suiteName:)` não grava no App Group do WhatsApp.

## Observação

Caso o aplicativo limpe as preferências na primeira inicialização, o
swizzle em `+[WDSLiquidGlass isEnabled]` mantém o recurso ativo mesmo
sem a flag persistida.