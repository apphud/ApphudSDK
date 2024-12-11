
#import <Foundation/Foundation.h>
#import "AMAStorageTrimming.h"

@class AMAStorageEventsTrimTransaction;

@interface AMAPlainStorageTrimmer : NSObject <AMAStorageTrimming>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithTrimTransaction:(AMAStorageEventsTrimTransaction *)trimTransaction;

@end
