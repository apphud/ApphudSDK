
#import "AMAConversionAttributionModelConfiguration.h"
#import "AMAAttributionMapping.h"

static NSString *const kAMAKeyMappings = @"mappings";

@implementation AMAConversionAttributionModelConfiguration

- (instancetype)initWithJSON:(NSDictionary *)json
{
    if (json == nil) {
        return nil;
    }
    NSMutableArray<AMAAttributionMapping *> *mutableMappings = [[NSMutableArray alloc] init];
    NSArray *mappingsJSON = json[kAMAKeyMappings];
    for (NSDictionary *mappingJson in mappingsJSON) {
        AMAAttributionMapping *mapping = [[AMAAttributionMapping alloc] initWithJSON:mappingJson];
        if (mapping != nil) {
            [mutableMappings addObject:mapping];
        }
    }
    return [self initWithMappings:mutableMappings];
}

- (instancetype)initWithMappings:(NSArray<AMAAttributionMapping *> *)mappings
{
    self = [super init];
    if (self != nil) {
        _mappings = [mappings copy];
    }
    return self;
}


- (NSDictionary *)JSON
{
    NSMutableArray *mappingsJson = [[NSMutableArray alloc] init];
    for (AMAAttributionMapping *mapping in self.mappings) {
        [mappingsJson addObject:[mapping JSON]];
    }
    return @{ kAMAKeyMappings : [mappingsJson copy] };
}

- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"self.mappings=%@", self.mappings];
    [description appendString:@">"];
    return description;
}


@end
