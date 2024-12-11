
#import <Foundation/Foundation.h>

@class AMAAttributionModelConfiguration;

@interface AMARevenueDeduplicator : NSObject

- (instancetype)initWithConfig:(AMAAttributionModelConfiguration *)config;
- (BOOL)checkForID:(NSString *)identifier;

@end
