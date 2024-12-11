
#import "AMALocationStorageState.h"

@implementation AMALocationStorageState

- (instancetype)initWithLocationIdentifier:(unsigned long long)locationIdentifier
                           visitIdentifier:(unsigned long long)visitIdentifier
                         requestIdentifier:(unsigned long long)requestIdentifier
                            locationsCount:(NSUInteger)locationsCount
                         firstLocationDate:(NSDate *)firstLocationDate
                               visitsCount:(NSUInteger)visitsCount
{
    self = [super init];
    if (self != nil) {
        _locationIdentifier = locationIdentifier;
        _requestIdentifier = requestIdentifier;
        _locationsCount = locationsCount;
        _firstLocationDate = firstLocationDate;
        _visitIdentifier = visitIdentifier;
        _visitsCount = visitsCount;
    }
    return self;
}

- (instancetype)stateByChangingLocationIdentifier:(unsigned long long)identifier
                                   locationsCount:(NSUInteger)count
                                firstLocationDate:(NSDate *)date
{
    return [[AMALocationStorageState alloc] initWithLocationIdentifier:identifier
                                                       visitIdentifier:self.visitIdentifier
                                                     requestIdentifier:self.requestIdentifier
                                                        locationsCount:count
                                                     firstLocationDate:date
                                                           visitsCount:self.visitsCount];
}

- (instancetype)stateByChangingLocationsCount:(NSUInteger)count
                            firstLocationDate:(NSDate *)date
{
    return [self stateByChangingLocationIdentifier:self.locationIdentifier
                                    locationsCount:count
                                 firstLocationDate:date];
}

- (instancetype)stateByChangingVisitIdentifier:(unsigned long long)identifier visitsCount:(NSUInteger)count
{
    return [[AMALocationStorageState alloc] initWithLocationIdentifier:self.locationIdentifier
                                                       visitIdentifier:identifier
                                                     requestIdentifier:self.requestIdentifier
                                                        locationsCount:self.locationsCount
                                                     firstLocationDate:self.firstLocationDate
                                                           visitsCount:count];
}

- (instancetype)stateByChangingRequestIdentifier:(unsigned long long)identifier
{
    return [[AMALocationStorageState alloc] initWithLocationIdentifier:self.locationIdentifier
                                                       visitIdentifier:self.visitIdentifier
                                                     requestIdentifier:identifier
                                                        locationsCount:self.locationsCount
                                                     firstLocationDate:self.firstLocationDate
                                                           visitsCount:self.visitsCount];
}

- (instancetype)stateByChangingVisitsCount:(NSUInteger)count
{
    return [[AMALocationStorageState alloc] initWithLocationIdentifier:self.locationIdentifier
                                                       visitIdentifier:self.visitIdentifier
                                                     requestIdentifier:self.requestIdentifier
                                                        locationsCount:self.locationsCount
                                                     firstLocationDate:self.firstLocationDate
                                                           visitsCount:count];
}

@end
