
#import "AMARevenueAttributionModelConfiguration.h"
#import "AMABoundMapping.h"
#import "AMACurrencyMapping.h"
#import "AMAEventFilter.h"

static NSString *const kAMAKeyMappings = @"mappings";
static NSString *const kAMAKeyEvents = @"events";
static NSString *const kAMAKeyCurrencyMapping = @"currency.mapping";

@implementation AMARevenueAttributionModelConfiguration

- (instancetype)initWithJSON:(NSDictionary *)json
{
    if (json == nil) {
        return nil;
    }
    NSArray *filtersJSON = json[kAMAKeyEvents];
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
    return [self initWithBoundMappings:mappings
                                events:filters
                       currencyMapping:[[AMACurrencyMapping alloc] initWithJSON:json[kAMAKeyCurrencyMapping]]];

}

- (instancetype)initWithBoundMappings:(NSArray<AMABoundMapping *> *)boundMappings
                               events:(NSArray<AMAEventFilter *> *)events
                      currencyMapping:(AMACurrencyMapping *)currencyMapping
{
    self = [super init];
    if (self != nil) {
        _boundMappings = [boundMappings copy];
        _events = [events copy];
        _currencyMapping = currencyMapping;
    }
    return self;
}


- (NSDictionary *)JSON
{
    NSMutableArray<NSDictionary *> *mappingsJson = [[NSMutableArray alloc] initWithCapacity:self.boundMappings.count];
    for (AMABoundMapping *mapping in self.boundMappings) {
        [mappingsJson addObject:[mapping JSON]];
    }
    NSMutableArray<NSDictionary *> *filtersJSON = [[NSMutableArray alloc] initWithCapacity:self.events.count];
    for (AMAEventFilter *eventFilter in self.events) {
        [filtersJSON addObject:[eventFilter JSON]];
    }
    return @{
        kAMAKeyEvents : [filtersJSON copy],
        kAMAKeyMappings : [mappingsJson copy],
        kAMAKeyCurrencyMapping  : [self.currencyMapping JSON],
    };
}

- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"self.boundMappings=%@", self.boundMappings];
    [description appendFormat:@", self.events=%@", self.events];
    [description appendFormat:@", self.currencyMapping=%@", self.currencyMapping];
    [description appendString:@">"];
    return description;
}


@end
