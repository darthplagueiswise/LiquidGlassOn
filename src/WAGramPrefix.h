// WAGramPrefix.h
#pragma once

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <substrate.h>
#endif

#define kWAGRLiquidGlassMaster @"wagr_liquidglass_master"
#define kWAGRDebugMode @"wagr_debug_mode"
#define WAGRPref(key) [[NSUserDefaults standardUserDefaults] boolForKey:(key)]