// WAGRBackup.m — clipboard JSON export/import of WAGram NSUserDefaults overrides.

#import "WAGRBackup.h"
#import "WAGRBackupScopePickerVC.h"
#import "../WAGramUI.h"

extern void WAGRWAABEnsureHooksInstalled(void);
extern void WAGRContextEnsureHooksInstalled(void);
extern void WAGRAuraGatingEnsureHooksInstalled(void);

static NSString *const kWAGRBackupMagic    = @"wagr_backup";
static NSString *const kWAGRBackupVersion  = @"version";
static NSString *const kWAGRBackupExported = @"exported_at";
static NSString *const kWAGRBackupWAAB     = @"waab";
static NSString *const kWAGRBackupContext  = @"context";

@implementation WAGRBackup

+ (BOOL)keyMatchesWAABScope:(NSString *)k {
    return [k hasPrefix:@"wagr.waab."] || [k hasPrefix:@"aura_"] ||
           [k isEqualToString:@"wagr_aura_simulation_enabled"];
}

+ (BOOL)keyMatchesContextScope:(NSString *)k {
    return [k hasPrefix:@"wagr.context."];
}

+ (NSDictionary *)snapshotForScope:(WAGRBackupScope)scope {
    NSMutableDictionary *root = [NSMutableDictionary dictionary];
    root[kWAGRBackupMagic]    = @YES;
    root[kWAGRBackupVersion]  = @1;
    root[kWAGRBackupExported] = @([NSDate.date timeIntervalSince1970]);

    NSDictionary *all = [NSUserDefaults.standardUserDefaults dictionaryRepresentation];
    NSMutableDictionary *waab = [NSMutableDictionary dictionary];
    NSMutableDictionary *ctx  = [NSMutableDictionary dictionary];

    for (NSString *k in all) {
        id v = all[k];
        if (!v) continue;
        if ((scope & WAGRBackupScopeWAAB) && [self keyMatchesWAABScope:k]) {
            waab[k] = v;
        } else if ((scope & WAGRBackupScopeContext) && [self keyMatchesContextScope:k]) {
            ctx[k] = v;
        }
    }
    if (scope & WAGRBackupScopeWAAB)    root[kWAGRBackupWAAB]    = waab;
    if (scope & WAGRBackupScopeContext) root[kWAGRBackupContext] = ctx;
    return root;
}

+ (NSUInteger)countForScope:(WAGRBackupScope)scope {
    NSUInteger n = 0;
    NSDictionary *all = [NSUserDefaults.standardUserDefaults dictionaryRepresentation];
    for (NSString *k in all) {
        if ((scope & WAGRBackupScopeWAAB)    && [self keyMatchesWAABScope:k])    n++;
        if ((scope & WAGRBackupScopeContext) && [self keyMatchesContextScope:k]) n++;
    }
    return n;
}

+ (NSData *)exportJSONForScope:(WAGRBackupScope)scope {
    NSDictionary *root = [self snapshotForScope:scope];
    NSError *err = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:root options:NSJSONWritingPrettyPrinted error:&err];
    return data;
}

+ (BOOL)valueIsSerializable:(id)v {
    return [v isKindOfClass:NSString.class] || [v isKindOfClass:NSNumber.class] ||
           [v isKindOfClass:NSArray.class]  || [v isKindOfClass:NSDictionary.class];
}

+ (BOOL)applyImport:(NSDictionary *)root scope:(WAGRBackupScope)scope error:(NSError **)err {
    if (![root isKindOfClass:NSDictionary.class] || ![root[kWAGRBackupMagic] boolValue]) {
        if (err) *err = [NSError errorWithDomain:@"WAGRBackup" code:1
                                        userInfo:@{NSLocalizedDescriptionKey: @"JSON não é um backup WAGram."}];
        return NO;
    }

    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;

    if (scope & WAGRBackupScopeWAAB) {
        for (NSString *k in [[ud dictionaryRepresentation] allKeys]) {
            if ([self keyMatchesWAABScope:k]) [ud removeObjectForKey:k];
        }
        NSDictionary *waab = root[kWAGRBackupWAAB];
        if ([waab isKindOfClass:NSDictionary.class]) {
            for (NSString *k in waab) {
                id v = waab[k];
                if ([self keyMatchesWAABScope:k] && [self valueIsSerializable:v])
                    [ud setObject:v forKey:k];
            }
        }
    }
    if (scope & WAGRBackupScopeContext) {
        for (NSString *k in [[ud dictionaryRepresentation] allKeys]) {
            if ([self keyMatchesContextScope:k]) [ud removeObjectForKey:k];
        }
        NSDictionary *ctx = root[kWAGRBackupContext];
        if ([ctx isKindOfClass:NSDictionary.class]) {
            for (NSString *k in ctx) {
                id v = ctx[k];
                if ([self keyMatchesContextScope:k] && [self valueIsSerializable:v])
                    [ud setObject:v forKey:k];
            }
        }
    }
    [ud synchronize];
    WAGRWAABEnsureHooksInstalled();
    WAGRContextEnsureHooksInstalled();
    WAGRAuraGatingEnsureHooksInstalled();
    return YES;
}

+ (void)presentExportFromVC:(UIViewController *)host {
    NSData *data = [self exportJSONForScope:WAGRBackupScopeAll];
    if (!data) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Falha"
                                                                   message:@"Não foi possível serializar overrides."
                                                            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [host presentViewController:a animated:YES completion:nil];
        return;
    }
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    UIPasteboard.generalPasteboard.string = json;

    NSUInteger waabN = [self countForScope:WAGRBackupScopeWAAB];
    NSUInteger ctxN  = [self countForScope:WAGRBackupScopeContext];

    UIAlertController *a = [UIAlertController
        alertControllerWithTitle:@"Backup copiado"
                         message:[NSString stringWithFormat:@"%lu chaves WAAB · %lu chaves Context\n\nCola em Notes ou outro app para guardar.",
                                  (unsigned long)waabN, (unsigned long)ctxN]
                  preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Compartilhar…" style:UIAlertActionStyleDefault handler:^(id _){
        UIActivityViewController *av = [[UIActivityViewController alloc]
            initWithActivityItems:@[json] applicationActivities:nil];
        [host presentViewController:av animated:YES completion:nil];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [host presentViewController:a animated:YES completion:nil];
}

+ (void)presentImportFromVC:(UIViewController *)host {
    NSString *clip = UIPasteboard.generalPasteboard.string;
    if (!clip.length) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Clipboard vazio"
                                                                   message:@"Cole um JSON de backup antes de importar."
                                                            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [host presentViewController:a animated:YES completion:nil];
        return;
    }
    NSData *data = [clip dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err = nil;
    id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
    if (!parsed || ![parsed isKindOfClass:NSDictionary.class] || ![parsed[kWAGRBackupMagic] boolValue]) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"JSON inválido"
                                                                   message:@"O clipboard não contém um backup WAGram válido."
                                                            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [host presentViewController:a animated:YES completion:nil];
        return;
    }

    NSDictionary *root = (NSDictionary *)parsed;
    NSUInteger waabN = [root[kWAGRBackupWAAB] isKindOfClass:NSDictionary.class] ? [(NSDictionary*)root[kWAGRBackupWAAB] count] : 0;
    NSUInteger ctxN  = [root[kWAGRBackupContext] isKindOfClass:NSDictionary.class] ? [(NSDictionary*)root[kWAGRBackupContext] count] : 0;

    WAGRBackupScopePickerVC *picker = [[WAGRBackupScopePickerVC alloc]
        initWithWAABCount:waabN contextCount:ctxN
                 onContinue:^(WAGRBackupScope scope){
        NSError *applyErr = nil;
        BOOL ok = [WAGRBackup applyImport:root scope:scope error:&applyErr];
        UIAlertController *result = [UIAlertController
            alertControllerWithTitle:ok ? @"Backup aplicado" : @"Falha"
                             message:ok ? [NSString stringWithFormat:@"Escopo aplicado: %@%@.\nReinicie WhatsApp se algumas flags não atualizarem na hora.",
                                            (scope & WAGRBackupScopeWAAB) ? @"WAAB" : @"",
                                            (scope & WAGRBackupScopeContext) ? ((scope & WAGRBackupScopeWAAB) ? @" + Context" : @"Context") : @""]
                                       : (applyErr.localizedDescription ?: @"Erro desconhecido.")
                      preferredStyle:UIAlertControllerStyleAlert];
        [result addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [host presentViewController:result animated:YES completion:nil];
    }];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
    [host presentViewController:nav animated:YES completion:nil];
}

@end
