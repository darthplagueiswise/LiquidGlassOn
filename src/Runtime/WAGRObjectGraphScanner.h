#pragma once
#import <Foundation/Foundation.h>

@interface WAGRObjectGraphNode : NSObject
@property(nonatomic, copy) NSString *ownerClass;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *valueClass;
@property(nonatomic, copy) NSString *address;
@end

@interface WAGRObjectGraphScanner : NSObject
+ (NSArray<WAGRObjectGraphNode *> *)scanSettingsContextGraph;
@end
