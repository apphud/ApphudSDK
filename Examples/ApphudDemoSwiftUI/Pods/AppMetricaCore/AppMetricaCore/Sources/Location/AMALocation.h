
#import <Foundation/Foundation.h>
#import "AMAIdentifiable.h"

@class CLLocation;

typedef NS_ENUM(NSUInteger, AMALocationProvider) {
    AMALocationProviderUnknown,
    AMALocationProviderGPS,
};

@interface AMALocation : NSObject <NSCopying, AMAIdentifiable>

@property (nonatomic, strong, readonly) NSDate *collectDate;
@property (nonatomic, strong, readonly) CLLocation *location;
@property (nonatomic, assign, readonly) AMALocationProvider provider;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithIdentifier:(NSNumber *)identifier
                       collectDate:(NSDate *)collectDate
                          location:(CLLocation *)location
                          provider:(AMALocationProvider)provider;

- (instancetype)locationByChangingIdentifier:(NSNumber *)identifier;

@end
