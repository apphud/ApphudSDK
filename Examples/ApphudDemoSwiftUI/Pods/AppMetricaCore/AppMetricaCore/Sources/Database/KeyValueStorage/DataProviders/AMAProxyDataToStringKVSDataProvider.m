
#import "AMAProxyDataToStringKVSDataProvider.h"

@interface AMAProxyDataToStringKVSDataProvider ()

@property (nonatomic, copy, readonly) id<AMAKeyValueStorageDataProviding> dataProvider;

@end

@implementation AMAProxyDataToStringKVSDataProvider

- (instancetype)initWithUnderlyingDataProvider:(id<AMAKeyValueStorageDataProviding>)dataPrivder
{
    self = [super init];
    if (self != nil) {
        _dataProvider = dataPrivder;
    }
    return self;
}

#pragma mark - AMAKeyValueStorageDataProviding -

- (NSArray<NSString *> *)allKeysWithError:(NSError **)error
{
    return [self.dataProvider allKeysWithError:error];
}

- (id)objectForKey:(NSString *)key error:(NSError **)error
{
    id obj = [self.dataProvider objectForKey:key error:error];
    if (obj == NSNull.null) {
        // pass
    }
    else if (obj != nil) {
        if ([obj isKindOfClass:NSString.class]) {
            return [[NSData alloc] initWithBase64EncodedString:obj options:0];
        }
        else {
            AMALogAssert(@"Expected NSString. Got %@ of `%@` type", obj, [obj class]);
        }
    }
    return obj;
}

- (NSDictionary<NSString *, id> *)objectsForKeys:(NSArray *)keys error:(NSError **)error
{
    NSDictionary *dict = [self.dataProvider objectsForKeys:keys error:error];
    NSMutableDictionary *mutableDict = [dict mutableCopy];
    
    for (NSString *key in dict.keyEnumerator) {
        if (dict[key] == NSNull.null) {
            mutableDict[key] = dict[key];
        }
        else if ([dict[key] isKindOfClass:NSString.class]) {
            mutableDict[key] = [[NSData alloc] initWithBase64EncodedString:dict[key] options:0];
        }
        else {
            AMALogAssert(@"Expected NSString. Got %@ of `%@` type", dict[key], [dict[key] class]);
        }
    }
    
    return [mutableDict copy];
}

- (BOOL)removeKey:(NSString *)key error:(NSError **)error
{
    return [self.dataProvider removeKey:key error:error];
}

- (BOOL)saveObject:(id)object forKey:(NSString *)key error:(NSError **)error
{
    if (object == NSNull.null) {
        // pass
    }
    else if (object != nil) {
        if ([object isKindOfClass:NSData.class]) {
            object = [object base64EncodedStringWithOptions:0];
        }
        else {
            AMALogAssert(@"Excpected NSData. Got %@ of `%@` type", object, [object class]);
        }
    }
    return [self.dataProvider saveObject:object forKey:key error:error];
}

- (BOOL)saveObjectsDictionary:(NSDictionary<NSString *, id> *)objectsDictionary error:(NSError **)error
{
    NSMutableDictionary *mutableDict = [objectsDictionary mutableCopy];
    
    for (NSString *key in objectsDictionary.keyEnumerator) {
        if (objectsDictionary[key] == NSNull.null) {
            mutableDict[key] = objectsDictionary[key];
        }
        else if ([objectsDictionary[key] isKindOfClass:NSData.class]) {
            mutableDict[key] = [mutableDict[key] base64EncodedStringWithOptions:0];
        }
        else {
            AMALogAssert(@"Excpected NSData. Got %@ of `%@` type",
                                 objectsDictionary[key], [objectsDictionary[key] class]);
        }
    }
    
    return [self.dataProvider saveObjectsDictionary:[mutableDict copy] error:error];
}

@end
