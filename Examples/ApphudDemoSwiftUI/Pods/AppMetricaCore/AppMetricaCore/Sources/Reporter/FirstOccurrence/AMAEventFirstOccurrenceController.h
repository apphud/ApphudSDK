
#import <Foundation/Foundation.h>
#import "AMAOptionalBool.h"

@class AMAEventNameHashesStorage;
@class AMAEventNameHashProvider;

@interface AMAEventFirstOccurrenceController : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithStorage:(AMAEventNameHashesStorage *)storage;
- (instancetype)initWithStorage:(AMAEventNameHashesStorage *)storage
                   hashProvider:(AMAEventNameHashProvider *)hashProvider
            maxEventHashesCount:(NSUInteger)maxEventHashesCount;

- (void)updateVersion;
- (AMAOptionalBool)isEventNameFirstOccurred:(NSString *)eventName;
- (void)resetHashes;

@end
