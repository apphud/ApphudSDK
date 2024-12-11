
#import "AMAVisit.h"

@implementation AMAVisit

@synthesize identifier = _identifier;

- (instancetype)initWithIdentifier:(NSNumber *)identifier
                       collectDate:(NSDate *)collectDate
                       arrivalDate:(NSDate *)arrivalDate
                     departureDate:(NSDate *)departureDate
                          latitude:(double)latitude
                         longitude:(double)longitude
                         precision:(double)precision
{
    self = [super init];
    if (self != nil) {
        _identifier = identifier;
        _collectDate = collectDate;
        _arrivalDate = arrivalDate;
        _departureDate = departureDate;
        _latitude = latitude;
        _longitude = longitude;
        _precision = precision;
    }

    return self;
}

+ (instancetype)visitWithIdentifier:(NSNumber *)identifier
                        collectDate:(NSDate *)collectDate
                        arrivalDate:(NSDate *)arrivalDate
                      departureDate:(NSDate *)departureDate
                           latitude:(double)latitude
                          longitude:(double)longitude
                          precision:(double)precision
{
    return [[self alloc] initWithIdentifier:identifier
                                collectDate:collectDate
                                arrivalDate:arrivalDate
                              departureDate:departureDate
                                   latitude:latitude
                                  longitude:longitude
                                  precision:precision];
}

- (instancetype)visitByChangingIdentifier:(NSNumber *)identifier
{
    return [[self class] visitWithIdentifier:identifier
                                 collectDate:self.collectDate
                                 arrivalDate:self.arrivalDate
                               departureDate:self.departureDate
                                    latitude:self.latitude
                                   longitude:self.longitude
                                   precision:self.precision];
}

@end
