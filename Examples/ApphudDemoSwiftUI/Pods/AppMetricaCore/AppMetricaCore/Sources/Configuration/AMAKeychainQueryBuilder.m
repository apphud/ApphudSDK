
#import "AMAKeychainQueryBuilder.h"

@interface AMAKeychainQueryBuilder ()

@property (nonatomic, copy) NSDictionary *parameters;

@end

@implementation AMAKeychainQueryBuilder

- (instancetype)initWithQueryParameters:(NSDictionary *)parameters
{
    self = [super init];
    if (self) {
        _parameters = [parameters copy];
    }

    return self;
}

- (NSDictionary *)entriesQuery
{
    return self.parameters;
}

- (NSDictionary *)entryQueryForKey:(id)key
{
    if (key == nil) {
        return nil;
    }

    NSMutableDictionary *parameters = [self.parameters mutableCopy];
    parameters[(__bridge id)kSecAttrAccount] = [key description];
    return parameters;
}

- (NSDictionary *)dataQueryForKey:(id)key
{
    NSMutableDictionary *parameters = [[self entryQueryForKey:key] mutableCopy];
    if (parameters != nil) {
        parameters[(__bridge id)kSecReturnData] = (__bridge id)kCFBooleanTrue;
        parameters[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    }

    return parameters;
}

- (NSDictionary *)addEntryQueryWithData:(NSData *)data forKey:(id)key
{
    if (data == nil) {
        return nil;
    }

    NSMutableDictionary *parameters = [[self entryQueryForKey:key] mutableCopy];
    if (parameters == nil) {
        return nil;
    }

    parameters[(__bridge id)kSecValueData] = data;
    return parameters;
}

- (nullable NSDictionary *)updateEntryQueryWithData:(NSData *)data
{
    if (data == nil) {
        return nil;
    }

    NSDictionary *parameters = @{
            (__bridge id)kSecValueData : data,
    };
    return parameters;
}

#if AMA_ALLOW_DESCRIPTIONS
- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", [super description]];
    [description appendFormat:@"self.parameters=%@", self.parameters];
    [description appendString:@">"];
    return description;
}
#endif

@end
