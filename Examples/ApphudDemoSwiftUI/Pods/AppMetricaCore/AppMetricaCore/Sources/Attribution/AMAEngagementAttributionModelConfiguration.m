
#import "AMAEngagementAttributionModelConfiguration.h"
#import "AMABoundMapping.h"
#import "AMAClientEventCondition.h"
#import "AMAECommerceEventCondition.h"
#import "AMARevenueEventCondition.h"
#import "AMAEventFilter.h"

static NSString *const kAMAKeyMappings = @"mappings";
static NSString *const kAMAKeyEventFilters = @"event.filters";

@implementation AMAEngagementAttributionModelConfiguration

- (instancetype)initWithJSON:(NSDictionary *)json
{
    if (json == nil) {
        return nil;
    }
    NSArray *filtersJSON = json[kAMAKeyEventFilters];
    NSMutableArray<AMAEventFilter *> *filters = [[NSMutableArray alloc] initWithCapacity:filtersJSON.count];
    for (NSDictionary *filterJSON in filtersJSON) {
        [filters addObject:[[AMAEventFilter alloc] initWithJSON:filterJSON]];
    }
    NSMutableArray<AMABoundMapping *> *mappings = [[NSMutableArray alloc] init];
    NSArray<NSDictionary *> *mappingsJson = json[kAMAKeyMappings];
    for (NSDictionary *mappingJson in mappingsJson) {
        AMABoundMapping *mapping = [[AMABoundMapping alloc] initWithJSON:mappingJson];
        if (mapping != nil) {
            [mappings addObject:mapping];
        }
    }
    return [self initWithEventFilters:filters boundMappings:mappings];
}

- (instancetype)initWithEventFilters:(NSArray<AMAEventFilter *> *)eventFilters
                       boundMappings:(NSArray<AMABoundMapping *> *)boundMappings
{
    self = [super init];
    if (self != nil) {
        _eventFilters = [eventFilters copy];
        _boundMappings = [boundMappings copy];
    }
    return self;
}


- (NSDictionary *)JSON
{
    NSMutableArray<NSDictionary *> *mappingsJson = [[NSMutableArray alloc] initWithCapacity:self.boundMappings.count];
    for (AMABoundMapping *mapping in self.boundMappings) {
        [mappingsJson addObject:[mapping JSON]];
    }
    NSMutableArray<NSDictionary *> *filtersJSON = [[NSMutableArray alloc] initWithCapacity:self.eventFilters.count];
    for (AMAEventFilter *eventFilter in self.eventFilters) {
        [filtersJSON addObject:[eventFilter JSON]];
    }
    return @{
        kAMAKeyEventFilters : [filtersJSON copy],
        kAMAKeyMappings : [mappingsJson copy],
    };
}

- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"self.boundMappings=%@", self.boundMappings];
    [description appendFormat:@", self.eventFilters=%@", self.eventFilters];
    [description appendString:@">"];
    return description;
}


@end
