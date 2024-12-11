
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import "AMACoreUtilsLogging.h"

@implementation AMAURLUtilities

#pragma mark - Public

+ (NSURL *)URLWithBaseURLString:(NSString *)baseURLString
              httpGetParameters:(NSDictionary *)httpGetParameters
{
    return [self URLWithBaseURLString:baseURLString pathComponents:@[] httpGetParameters:httpGetParameters];
}

+ (NSURL *)URLWithBaseURLString:(NSString *)baseURLString
                 pathComponents:(NSArray *)pathComponents
              httpGetParameters:(NSDictionary *)httpGetParameters
{
    if (baseURLString.length == 0) {
        AMALogAssert(@"Base URL is empty");
        return nil;
    }

    NSURL *url = nil;
    NSURL *baseURL = [self createBaseURL:baseURLString];

    if (baseURL != nil) {
        NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:baseURL resolvingAgainstBaseURL:NO];
        if (httpGetParameters.count > 0) {
            [self appendQueryItemsForURLComponents:urlComponents fromDictionary:httpGetParameters];
        }

        url = [urlComponents URL];
        if (pathComponents.count > 0) {
            url = [self URLByAppendingPathComponentsForURL:url fromArray:pathComponents];
        }
    }
    return url;
}

+ (NSDictionary *)HTTPGetParametersForURL:(NSURL *)url
{
    if (url == nil) {
        return @{};
    }
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    for (NSURLQueryItem *item in urlComponents.queryItems) {
        NSString *key = item.name;
        if (key != nil) {
            parameters[key] = item.value;
        }
    }
    return [parameters copy];
}

#pragma mark - Private

+ (NSURL *)createBaseURL:(NSString *)baseURLString
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 170000 || __TV_OS_VERSION_MAX_ALLOWED >= 170000
    if (@available(iOS 17.0, tvOS 17.0, *)) {
        return [NSURL URLWithString:baseURLString encodingInvalidCharacters:NO];
    }
#endif
    return [NSURL URLWithString:baseURLString];
}

+ (void)appendQueryItemsForURLComponents:(NSURLComponents *)urlComponents fromDictionary:(NSDictionary *)dictionary
{
    NSMutableArray *queryItems =
        [urlComponents.queryItems mutableCopy] ?: [NSMutableArray arrayWithCapacity:dictionary.count];
    [dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        NSString *keyString = [self stringForObject:key];
        NSString *valueString = [self stringForObject:value];
        NSURLQueryItem *queryItem = [NSURLQueryItem queryItemWithName:keyString value:valueString];
        [queryItems addObject:queryItem];
    }];
    urlComponents.queryItems = [queryItems copy];
}

+ (NSURL *)URLByAppendingPathComponentsForURL:(NSURL *)url fromArray:(NSArray *)pathComponents
{
    NSURL *result = url;
    for (NSString *pathComponent in pathComponents) {
        result = [result URLByAppendingPathComponent:pathComponent isDirectory:NO];
    }
    return result;
}

+ (NSString *)stringForObject:(id)object
{
    NSString *result = nil;
    if ([object isKindOfClass:[NSString class]]) {
        result = object;
    }
    else if ([object isKindOfClass:[NSNumber class]]) {
        NSNumber *number = (NSNumber *)object;
        result = [number stringValue];
    }
    else if ([object isKindOfClass:[NSNull class]]) {
        result = @"";
    }
    else {
        AMALogAssert(@"Unexpected type of object: %@", [object class]);
        result = @"";
    }
    return result;
}

@end
