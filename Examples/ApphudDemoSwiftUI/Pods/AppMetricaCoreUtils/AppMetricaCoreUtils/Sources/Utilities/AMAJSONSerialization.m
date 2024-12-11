
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import "AMACoreUtilsLogging.h"

@implementation AMAJSONSerialization

#pragma mark - Public

+ (NSString *)stringWithJSONObject:(id)object error:(NSError **)error
{
    NSData *data = [self dataWithJSONObject:object error:error];
    if (data == nil) {
        return nil;
    }
    
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (string == nil) {
        AMALogAssert(@"Failed to deserialize string from JSON data");
        [AMAErrorUtilities fillError:error
                           withError:[[self class] malformedJSONError:@{@"Can't deserialize data" : object}]];
    }
    return string;
}

+ (NSData *)dataWithJSONObject:(id)object error:(NSError **)error
{
    if (object == nil) {
        return nil;
    }
    
    if ([NSJSONSerialization isValidJSONObject:object] == NO) {
        AMALogAssert(@"Failed to serialize object into JSON: %@", object);
        [AMAErrorUtilities fillError:error
                           withError:[[self class] malformedJSONError:@{@"Wrong JSON object" : object}]];
        return nil;
    }
    
    return [NSJSONSerialization dataWithJSONObject:object options:0 error:error];
}

+ (NSDictionary *)dictionaryWithJSONString:(NSString *)JSONString error:(NSError **)error
{
    return [self dictionaryWithJSONData:[self dataForJSONString:JSONString error:error] error:error];
}

+ (NSArray *)arrayWithJSONString:(NSString *)JSONString error:(NSError **)error
{
    return [self arrayWithJSONData:[self dataForJSONString:JSONString error:error] error:error];
}

+ (NSDictionary *)dictionaryWithJSONData:(NSData *)JSONString error:(NSError **)error
{
    NSDictionary *dictionary = [self objectWithJSONData:JSONString error:error];
    if (dictionary != nil && [dictionary isKindOfClass:[NSDictionary class]] == NO) {
        [AMAErrorUtilities fillError:error
                           withError:[[self class] unexpectedJSONErrorWithResultObject:dictionary]];
        return nil;
    }
    return dictionary;
}

+ (NSArray *)arrayWithJSONData:(NSData *)JSONString error:(NSError **)error
{
    NSArray *array = [self objectWithJSONData:JSONString error:error];
    if (array != nil && [array isKindOfClass:[NSArray class]] == NO) {
        [AMAErrorUtilities fillError:error
                           withError:[[self class] unexpectedJSONErrorWithResultObject:array]];
        return nil;
    }
    return array;
}

#pragma mark - Private

+ (NSData *)dataForJSONString:(NSString *)JSONString error:(NSError **)error
{
    if (JSONString == nil) {
        return nil;
    }
    
    NSData *data = [JSONString dataUsingEncoding:NSUTF8StringEncoding];
    if (data == nil) {
        AMALogAssert(@"Failed to serialize string into data");
        [AMAErrorUtilities fillError:error
                           withError:[[self class] malformedJSONError:@{@"Can't serialize data" : JSONString}]];
    }
    return data;
}

+ (id)objectWithJSONData:(NSData *)data error:(NSError **)error
{
    if (data == nil) {
        return nil;
    }
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
}

#pragma mark - Errors

+ (NSError *)malformedJSONError:(NSDictionary *)params
{
    NSString *errorMsg =
    [NSString stringWithFormat:@"Passed dictionary is not a valid serializable JSON object: %@", params];
    return [AMAErrorUtilities internalErrorWithCode:AMAAppMetricaInternalEventJsonSerializationError
                                        description:errorMsg];
}

+ (NSError *)unexpectedJSONErrorWithResultObject:(id)result
{
    NSDictionary *userInfo = nil;
    if (result != nil) {
        userInfo = @{ kAMAAppMetricaInternalErrorResultObjectKey : result };
    }
    return [NSError errorWithDomain:kAMAAppMetricaInternalErrorDomain
                               code:AMAAppMetricaInternalEventErrorCodeUnexpectedDeserialization
                           userInfo:userInfo];
}


@end
