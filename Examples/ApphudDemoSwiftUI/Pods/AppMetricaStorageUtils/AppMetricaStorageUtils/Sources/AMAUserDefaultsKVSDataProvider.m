
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>

@interface AMAUserDefaultsKVSDataProvider ()

@property (nonatomic, strong, readonly) NSUserDefaults *userDefaults;

@end

@implementation AMAUserDefaultsKVSDataProvider

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults
{
    self = [super init];
    if (self != nil) {
        _userDefaults = userDefaults;
    }
    return self;
}

- (NSArray<NSString *> *)allKeysWithError:(NSError **)error
{
    return [self.userDefaults.dictionaryRepresentation.allKeys copy];
}

- (id)objectForKey:(NSString *)key error:(NSError **)error
{
    return [self.userDefaults objectForKey:key];
}

- (NSDictionary<NSString *,id> *)objectsForKeys:(NSArray *)keys error:(NSError **)error
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSString *key in keys) {
        result[key] = [self.userDefaults objectForKey:key];
    }
    return [result copy];
}

- (BOOL)removeKey:(NSString *)key error:(NSError **)error
{
    [self.userDefaults removeObjectForKey:key];
    return YES;
}

- (BOOL)saveObject:(id)object forKey:(NSString *)key error:(NSError **)error
{
    if (object == [NSNull null]) {
        [self.userDefaults removeObjectForKey:key];
    } else {
        [self.userDefaults setObject:object forKey:key];
    }
    return YES;
}

- (BOOL)saveObjectsDictionary:(NSDictionary<NSString *,id> *)objectsDictionary error:(NSError **)error
{
    [objectsDictionary enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        [self saveObject:obj forKey:key error:NULL];
    }];
    return YES;
}

@end
