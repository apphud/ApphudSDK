
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

@implementation AMACollectionUtilities

+ (NSDictionary *)filteredDictionary:(NSDictionary *)sourceDictionary withKeys:(NSSet *)keys
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSString *key in keys) {
        result[key] = sourceDictionary[key];
    }
    return [result copy];
}

+ (NSDictionary *)dictionaryByRemovingEmptyStringValuesForDictionary:(NSDictionary *)sourceDictionary
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    [sourceDictionary enumerateKeysAndObjectsUsingBlock:^(id key, NSString *value, BOOL *stop) {
        if ([value isKindOfClass:[NSString class]] == NO || value.length > 0) {
            result[key] = value;
        }
    }];
    return [result copy];
}

+ (BOOL)areAllItemsOfDictionary:(NSDictionary *)dictionary matchBlock:(BOOL(^)(id key, id value))block
{
    NSParameterAssert(block != nil);

    __block BOOL result = YES;
    [dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (block(key, obj) == NO) {
            result = NO;
            *stop = YES;
        }
    }];
    return result;
}

+ (NSArray *)filteredArray:(NSArray *)array withPredicate:(BOOL(^)(id item))block
{
    NSParameterAssert(block != nil);

    NSPredicate *filterPredicate = [NSPredicate predicateWithBlock:^BOOL(id item, NSDictionary *bindings) {
        return block(item);
    }];
    NSArray *filtered = [array filteredArrayUsingPredicate:filterPredicate];
    return filtered;
}

+ (NSArray *)mapArray:(NSArray *)array withBlock:(id(^)(id item))block
{
    NSParameterAssert(block != nil);

    NSMutableArray *result = [NSMutableArray arrayWithCapacity:array.count];
    for (id item in array) {
        id newItem = block(item);
        if (newItem != nil) {
            [result addObject:newItem];
        }
    }
    return [result copy];
}

+ (NSArray *)flatMapArray:(NSArray *)array withBlock:(NSArray *(^)(id item))block
{
    NSParameterAssert(block != nil);
    
    NSMutableArray *result = [NSMutableArray new];
    for (id item in array) {
        NSArray *newItems = block(item);
        if (newItems != nil) {
            [result addObjectsFromArray:newItems];
        }
    }
    return [result copy];
}

+ (BOOL)areAllItemsOfArray:(NSArray *)array matchBlock:(BOOL(^)(id item))block
{
    NSParameterAssert(block != nil);

    __block BOOL result = YES;
    [array enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (block(obj) == NO) {
            result = NO;
            *stop = YES;
        }
    }];
    return result;
}

+ (NSDictionary *)compactMapValuesOfDictionary:(NSDictionary *)dictionary withBlock:(id(^)(id key, id value))block
{
    NSParameterAssert(block != nil);
    
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    [dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id val, BOOL *stop) {
        id newObject = block(key, val);
        if (newObject != nil) {
            result[key] = newObject;
        }
    }];
    return result.copy;
}

+ (void)removeItemsFromArray:(NSMutableArray *)array withBlock:(void(^)(id item, BOOL *remove))block
{
    NSParameterAssert(block != nil);

    NSUInteger index = 0;
    while (index < array.count) {
        id obj = array[index];
        BOOL shouldRemove = NO;
        block(obj, &shouldRemove);
        if (shouldRemove) {
            [array removeObjectAtIndex:index];
        }
        else {
            ++index;
        }
    }
}

@end
