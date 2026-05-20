#import "WAGramPrefix.h"
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

NS_ASSUME_NONNULL_BEGIN

void WAInstallKeychainPatchIfNeeded(void);
NSString *WAKeychainAccessGroupDiagnostic(void);

NS_ASSUME_NONNULL_END

#ifdef __cplusplus
}
#endif
