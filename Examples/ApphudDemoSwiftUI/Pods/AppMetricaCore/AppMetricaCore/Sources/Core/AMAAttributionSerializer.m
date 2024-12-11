
#import "AMAAttributionSerializer.h"
#import "AMAPair.h"

static const NSString *kAMAKeyKey = @"key";
static const NSString *kAMAKeyValue = @"value";

@implementation AMAAttributionSerializer

#pragma mark - Public -

+ (NSArray *)toJsonArray:(NSArray<AMAPair *> *)model
{
    NSMutableArray *jsonArray = [[NSMutableArray alloc] initWithCapacity:model.count];
    for (AMAPair *pair in model) {
        [jsonArray addObject:[self pairToJson:pair]];
    }
    return [jsonArray copy];
}

+ (NSArray<AMAPair *> *)fromJsonArray:(NSArray *)json
{
    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:json.count];
    for (id item in json) {
        AMAPair *pair = [self jsonToPair:item];
        if (pair != nil) {
            [array addObject:pair];
        }
    }
    return [array copy];
}

#pragma mark - Private -

+ (NSDictionary *)pairToJson:(AMAPair *)pair
{
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] initWithCapacity:2];
    dictionary[kAMAKeyKey] = pair.key;
    dictionary[kAMAKeyValue] = pair.value;
    return [dictionary copy];
}

+ (AMAPair *)jsonToPair:(id)json
{
    if ([json isKindOfClass:[NSDictionary class]] == NO) {
        return nil;
    }
    id key = json[kAMAKeyKey];
    id value = json[kAMAKeyValue];
    if ((key == nil || [key isKindOfClass: [NSString class]]) &&
        (value == nil || [value isKindOfClass: [NSString class]])) {
        return [[AMAPair alloc] initWithKey:key value:value];
    }
    else {
        return nil;
    }
}

@end
