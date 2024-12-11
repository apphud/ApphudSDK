
#import "AMAInMemoryKeyValueStorageDataProvider.h"
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

@interface AMAInMemoryKeyValueStorageDataProvider ()

@property (nonatomic, strong, readonly) NSMutableDictionary *dictionary;

@end

@implementation AMAInMemoryKeyValueStorageDataProvider

- (instancetype)init
{
    return [self initWithDictionary:[NSMutableDictionary dictionary]];
}

- (NSArray<NSString *> *)allKeysWithError:(NSError **)error
{
    @synchronized (self) {
        return self.dictionary.allKeys;
    }
}

- (instancetype)initWithDictionary:(NSMutableDictionary *)dictionary
{
    self = [super init];
    if (self != nil) {
        _dictionary = dictionary;
    }
    return self;
}

- (BOOL)removeKey:(NSString *)key error:(NSError **)error
{
    @synchronized (self) {
        self.dictionary[key] = [NSNull null];
        return YES;
    }
}

- (id)objectForKey:(NSString *)key error:(NSError **)error
{
    @synchronized (self) {
        id value = self.dictionary[key];
        return value == [NSNull null] ? nil : value;
    }
}

- (BOOL)saveObject:(id)object forKey:(NSString *)key error:(NSError **)error
{
    @synchronized (self) {
        self.dictionary[key] = object;
        return YES;
    }
}

- (NSDictionary<NSString *, id> *)objectsForKeys:(NSArray *)keys error:(NSError **)error
{
    @synchronized (self) {
        return [AMACollectionUtilities filteredDictionary:self.dictionary
                                                 withKeys:[NSSet setWithArray:keys]];
    }
}

- (BOOL)saveObjectsDictionary:(NSDictionary<NSString *, id> *)objectsDictionary error:(NSError **)error
{
    @synchronized (self) {
        [objectsDictionary enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
            [self saveObject:value forKey:key error:nil];
        }];
        return YES;
    }
}

@end
