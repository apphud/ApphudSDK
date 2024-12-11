
#import <Foundation/Foundation.h>
#import "AMAStorageTrimming.h"

@class AMAStorageEventsTrimTransaction;

@interface AMAEventsCountStorageTrimmer : NSObject <AMAStorageTrimming>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithApiKey:(NSString *)apiKey
               trimTransaction:(AMAStorageEventsTrimTransaction *)trimTransaction;

- (void)handleEventAdding;

@end
