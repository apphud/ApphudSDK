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

#import "AMAArrayIterator.h"
#import "AMABlockTimer.h"
#import "AMABroadcasting.h"
#import "AMABytesStringTruncator.h"
#import "AMACollectionUtilities.h"
#import "AMADataEncoding.h"
#import "AMADataTruncator.h"
#import "AMADateProvider.h"
#import "AMADateProviding.h"
#import "AMADecimalUtils.h"
#import "AMADictionaryRepresentation.h"
#import "AMAErrorUtilities.h"
#import "AMAExecuting.h"
#import "AMAExecutionCondition.h"
#import "AMAFailureDispatcher.h"
#import "AMAFileUtility.h"
#import "AMAFirstExecutionCondition.h"
#import "AMAFullDataTruncator.h"
#import "AMAGapExecutionCondition.h"
#import "AMAIdentifierValidator.h"
#import "AMAIntervalExecutionCondition.h"
#import "AMAIterable.h"
#import "AMAJSONSerialization.h"
#import "AMALengthStringTruncator.h"
#import "AMAMultiTimer.h"
#import "AMANumberUtilities.h"
#import "AMAPermissiveTruncator.h"
#import "AMAQueuesFactory.h"
#import "AMATimer.h"
#import "AMATimeUtilities.h"
#import "AMATruncating.h"
#import "AMATruncatorsFactory.h"
#import "AMAURLUtilities.h"
#import "AMAValidationUtilities.h"
#import "AMAVersionUtils.h"
#import "AppMetricaCoreUtils.h"

FOUNDATION_EXPORT double AppMetricaCoreUtilsVersionNumber;
FOUNDATION_EXPORT const unsigned char AppMetricaCoreUtilsVersionString[];

