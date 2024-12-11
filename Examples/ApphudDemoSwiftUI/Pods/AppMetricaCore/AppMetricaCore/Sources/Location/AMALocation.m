
#import "AMALocation.h"

@implementation AMALocation

@synthesize identifier = _identifier;

- (instancetype)initWithIdentifier:(NSNumber *)identifier
                       collectDate:(NSDate *)collectDate
                          location:(CLLocation *)location
                          provider:(AMALocationProvider)provider
{
    self = [super init];
    if (self != nil) {
        _identifier = identifier;
        _collectDate = collectDate;
        _location = location;
        _provider = provider;
    }
    return self;
}

- (instancetype)locationByChangingIdentifier:(NSNumber *)identifier
{
    return [[AMALocation alloc] initWithIdentifier:identifier
                                       collectDate:self.collectDate
                                          location:self.location
                                          provider:self.provider];
}

- (id)copyWithZone:(nullable NSZone *)zone
{
    return self;
}

#if AMA_ALLOW_DESCRIPTIONS

- (NSString *)description
{
    return [self debugDescription];
}

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"<%@ (%@ from %lu at %@)%@>",
                                      [super debugDescription],
                                      self.identifier,
                                      (unsigned long)self.provider,
                                      self.collectDate,
                                      self.location];
}

#endif

@end
