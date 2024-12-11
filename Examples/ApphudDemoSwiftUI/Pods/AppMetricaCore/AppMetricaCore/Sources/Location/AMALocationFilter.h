
#import <Foundation/Foundation.h>

@class AMALocationCollectingConfiguration;
@class CLLocation;

@interface AMALocationFilter : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithConfiguration:(AMALocationCollectingConfiguration *)configuration;

- (BOOL)shouldAddLocation:(CLLocation *)location atDate:(NSDate *)date;
- (void)updateLastLocation:(CLLocation *)location atDate:(NSDate *)date;

@end
