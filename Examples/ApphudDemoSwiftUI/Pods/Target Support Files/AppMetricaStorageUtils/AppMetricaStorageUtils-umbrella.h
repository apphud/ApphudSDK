#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "AMADiskFileStorage.h"
#import "AMAFileStorage.h"
#import "AMAIncrementableValueStorage.h"
#import "AMAIncrementableValueStorageFactory.h"
#import "AMAKeyValueStorageDataProviding.h"
#import "AMAKeyValueStorageProviding.h"
#import "AMAKeyValueStoring.h"
#import "AMARollbackHolder.h"
#import "AMAUserDefaultsKVSDataProvider.h"
#import "AMAUserDefaultsStorage.h"
#import "AppMetricaStorageUtils.h"

FOUNDATION_EXPORT double AppMetricaStorageUtilsVersionNumber;
FOUNDATION_EXPORT const unsigned char AppMetricaStorageUtilsVersionString[];

