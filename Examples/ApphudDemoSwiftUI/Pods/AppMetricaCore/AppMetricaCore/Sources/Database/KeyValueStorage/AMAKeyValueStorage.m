
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>
#import "AMAKeyValueStorage.h"
#import "AMAKeyValueStorageConverting.h"

@implementation AMAKeyValueStorage

- (instancetype)initWithDataProvider:(id<AMAKeyValueStorageDataProviding>)dataProvider
                           converter:(id<AMAKeyValueStorageConverting>)converter
{
    self = [super init];
    if (self != nil) {
        _dataProvider = dataProvider;
        _converter = converter;
    }
    return self;
}

#define SAVE(val, conv) \
    if ((val) == nil) { \
        return [self.dataProvider removeKey:key error:error]; \
    } \
    return [self.dataProvider saveObject:(conv) forKey:key error:error]; \

#define GET(conv) \
    id value = [self.dataProvider objectForKey:key error:error]; \
    return value == nil ? nil : (conv);

- (NSString *)stringForKey:(NSString *)key error:(NSError **)error
{
    GET([self.converter stringForObject:value]);
}

- (BOOL)saveString:(NSString *)string forKey:(NSString *)key error:(NSError **)error
{
    SAVE(string, [self.converter objectForString:string]);
}

- (NSData *)dataForKey:(NSString *)key error:(NSError **)error
{
    GET([self.converter dataForObject:value]);
}

- (BOOL)saveData:(NSData *)data forKey:(NSString *)key error:(NSError **)error
{
    SAVE(data, [self.converter objectForData:data]);
}

- (NSNumber *)boolNumberForKey:(NSString *)key error:(NSError **)error
{
    GET([NSNumber numberWithBool:[self.converter boolForObject:value]]);
}

- (BOOL)saveBoolNumber:(NSNumber *)value forKey:(NSString *)key error:(NSError **)error
{
    SAVE(value, [self.converter objectForBool:value.boolValue]);
}

- (NSNumber *)longLongNumberForKey:(NSString *)key error:(NSError **)error
{
    GET([NSNumber numberWithLongLong:[self.converter longLongForObject:value]]);
}

- (BOOL)saveLongLongNumber:(NSNumber *)value forKey:(NSString *)key error:(NSError **)error
{
    SAVE(value, [self.converter objectForLongLong:value.longLongValue]);
}

- (NSNumber *)unsignedLongLongNumberForKey:(NSString *)key error:(NSError **)error
{
    GET([NSNumber numberWithUnsignedLongLong:[self.converter unsignedLongLongForObject:value]]);
}

- (BOOL)saveUnsignedLongLongNumber:(NSNumber *)value forKey:(NSString *)key error:(NSError **)error
{
    SAVE(value, [self.converter objectForUnsignedLongLong:value.unsignedLongLongValue]);
}

- (NSNumber *)doubleNumberForKey:(NSString *)key error:(NSError **)error
{
    GET([NSNumber numberWithDouble:[self.converter doubleForObject:value]]);
}

- (BOOL)saveDoubleNumber:(NSNumber *)value forKey:(NSString *)key error:(NSError **)error
{
    SAVE(value, [self.converter objectForDouble:value.doubleValue]);
}

- (NSDate *)dateForKey:(NSString *)key error:(NSError **)error
{
    GET([self.converter dateForObject:value]);
}

- (BOOL)saveDate:(NSDate *)date forKey:(NSString *)key error:(NSError **)error
{
    SAVE(date, [self.converter objectForDate:date]);
}

- (NSDictionary *)jsonDictionaryForKey:(NSString *)key error:(NSError **)error
{
    GET([self jsonDictionaryForString:[self.converter stringForObject:value] error:error]);
}

- (BOOL)saveJSONDictionary:(NSDictionary *)value forKey:(NSString *)key error:(NSError **)error
{
    SAVE(value, [self.converter objectForString:[self stringForJSONObject:value error:error]]);
}

- (NSArray *)jsonArrayForKey:(NSString *)key error:(NSError **)error
{
    GET([self jsonArrayForString:[self.converter stringForObject:value] error:error]);
}

- (BOOL)saveJSONArray:(NSArray *)value forKey:(NSString *)key error:(NSError **)error
{
    SAVE(value, [self.converter objectForString:[self stringForJSONObject:value error:error]]);
}

#undef SAVE
#undef GET

- (NSDictionary *)jsonDictionaryForString:(NSString *)jsonString error:(NSError **)error
{
    NSDictionary *result = [AMAJSONSerialization dictionaryWithJSONString:jsonString error:error];
    return result;
}

- (NSArray *)jsonArrayForString:(NSString *)jsonString error:(NSError **)error
{
    NSArray *result = [AMAJSONSerialization arrayWithJSONString:jsonString error:error];
    return result;
}

- (NSString *)stringForJSONObject:(id)value error:(NSError **)error
{
    return [AMAJSONSerialization stringWithJSONObject:value error:error];
}

#if AMA_ALLOW_DESCRIPTIONS

- (NSString *)description
{
    NSMutableDictionary *pairs = [NSMutableDictionary dictionary];
    for (NSString *key in [self.dataProvider allKeysWithError:nil]) {
        pairs[key] = [self.dataProvider objectForKey:key error:nil] ?: @"error";
    }
    return [NSString stringWithFormat:@"[%@ %@]", [super description], pairs];
}

#endif

@end
