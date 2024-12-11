
#import <Foundation/Foundation.h>
#import "AMAIdentifiable.h"

@interface AMAVisit : NSObject <AMAIdentifiable>

@property (nonatomic, strong, readonly) NSDate *collectDate;
@property (nonatomic, strong, readonly) NSDate *arrivalDate;
@property (nonatomic, strong, readonly) NSDate *departureDate;
@property (nonatomic, assign, readonly) double latitude;
@property (nonatomic, assign, readonly) double longitude;
@property (nonatomic, assign, readonly) double precision;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithIdentifier:(NSNumber *)identifier
                       collectDate:(NSDate *)collectDate
                       arrivalDate:(NSDate *)arrivalDate
                     departureDate:(NSDate *)departureDate
                          latitude:(double)latitude
                         longitude:(double)longitude
                         precision:(double)precision;

+ (instancetype)visitWithIdentifier:(NSNumber *)identifier
                        collectDate:(NSDate *)collectDate
                        arrivalDate:(NSDate *)arrivalDate
                      departureDate:(NSDate *)departureDate
                           latitude:(double)latitude
                          longitude:(double)longitude
                          precision:(double)precision;

- (instancetype)visitByChangingIdentifier:(NSNumber *)identifier;

@end
