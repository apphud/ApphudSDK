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

#import "AMAFMDatabase.h"
#import "AMAFMDatabaseAdditions.h"
#import "AMAFMDatabasePool.h"
#import "AMAFMDatabaseQueue.h"
#import "AMAFMResultSet.h"
#import "AppMetricaFMDB.h"

FOUNDATION_EXPORT double AppMetricaFMDBVersionNumber;
FOUNDATION_EXPORT const unsigned char AppMetricaFMDBVersionString[];

