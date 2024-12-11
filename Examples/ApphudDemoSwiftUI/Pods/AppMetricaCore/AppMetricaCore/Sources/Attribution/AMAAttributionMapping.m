
#import "AMAAttributionMapping.h"
#import "AMAClientEventCondition.h"
#import "AMAECommerceEventCondition.h"
#import "AMARevenueEventCondition.h"
#import "AMAEventFilter.h"

static NSString *const kAMAEventFilters = @"event.filters";
static NSString *const kAMARequiredCount = @"required.count";
static NSString *const kAMAConversionValueDiff = @"conversion.value.diff";

@implementation AMAAttributionMapping

- (instancetype)initWithJSON:(NSDictionary *)json
{
    if (json == nil) {
        return nil;
    }
    NSArray *filtersJSON = json[kAMAEventFilters];
    NSMutableArray<AMAEventFilter *> *filters = [[NSMutableArray alloc] initWithCapacity:filtersJSON.count];
    if (filtersJSON != nil) {
        for (NSDictionary *filterJSON in filtersJSON) {
            [filters addObject:[[AMAEventFilter alloc] initWithJSON:filterJSON]];
        }
    }
    NSNumber *requiredCountNumber = json[kAMARequiredCount];
    NSNumber *conversionValueDiff = json[kAMAConversionValueDiff];
    return [self initWithEventFilters:filters
                        requiredCount:requiredCountNumber.unsignedIntegerValue
                  conversionValueDiff:conversionValueDiff.integerValue];
}

- (instancetype)initWithEventFilters:(NSArray<AMAEventFilter *> *)eventFilters
                       requiredCount:(NSUInteger)requiredCount
                 conversionValueDiff:(NSInteger)conversionValueDiff
{
    self = [super init];
    if (self != nil) {
        _eventFilters = [eventFilters copy];
        _requiredCount = requiredCount;
        _conversionValueDiff = conversionValueDiff;
    }
    return self;
}

- (NSDictionary *)JSON
{
    NSMutableArray<NSDictionary *> *filtersJSON = [[NSMutableArray alloc] initWithCapacity:self.eventFilters.count];
    for (AMAEventFilter *eventFilter in self.eventFilters) {
        [filtersJSON addObject:[eventFilter JSON]];
    }
    return @{
        kAMAEventFilters : filtersJSON,
        kAMARequiredCount: @(self.requiredCount),
        kAMAConversionValueDiff : @(self.conversionValueDiff)
    };
}

- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"self.eventFilters=%@", self.eventFilters];
    [description appendFormat:@", self.requiredCount=%lu", (unsigned long) self.requiredCount];
    [description appendFormat:@", self.conversionValueDiff=%ld", (long) self.conversionValueDiff];
    [description appendString:@">"];
    return description;
}


@end
