
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>
#import "AMACachingKeyValueStorage.h"

typedef BOOL(^AMASetterBlock)(id<AMAKeyValueStoring> storage, NSError **internalError);
typedef id(^AMAGetterBlock)(id<AMAKeyValueStoring> storage, NSError **internalError);

@interface AMACachingKeyValueStorage ()

@property (nonatomic, strong, readonly) id<AMAKeyValueStoring> storage;

@property (nonatomic, strong, readonly) NSMutableDictionary *cache;
@property (nonatomic, strong, readonly) NSMutableDictionary *delayedUpdates;
@property (nonatomic, assign) BOOL shouldDelay;

@property (nonatomic, strong) NSObject *cacheLock;
@property (nonatomic, strong) NSObject *dbLock;

@end

@implementation AMACachingKeyValueStorage

- (instancetype)initWithStorage:(id<AMAKeyValueStoring>)storage
{
    self = [super init];
    if (self != nil) {
        _storage = storage;
        _cache = [NSMutableDictionary dictionary];
        _delayedUpdates = [NSMutableDictionary dictionary];
        _shouldDelay = YES;

        _cacheLock = [[NSObject alloc] init];
        _dbLock = [[NSObject alloc] init];
    }
    return self;
}

- (id)valueForKey:(NSString *)key valueClass:(Class)valueClass error:(NSError **)error getterBlock:(AMAGetterBlock)block
{
    [self openDatabaseIfMissedCacheForKey:key getterBlock:block];
    @synchronized (self.cacheLock) {
        id value = self.cache[key];
        if (value == nil) {
            @synchronized (self.dbLock) {
                [self applyDelayedUpdates];
                value = block(self.storage, error);
            }
            self.cache[key] = value ?: [NSNull null];
        }
        else if (value == [NSNull null]) {
            value = nil;
        }
        else if ([value isKindOfClass:valueClass] == NO) {
            AMALogAssert(@"Invalid cached value type for key '%@'. Cached: %@, expected: %@",
                                 key, [value class], valueClass);
            value = nil;
        }
        return value;
    }
}

- (void)openDatabaseIfMissedCacheForKey:(NSString *)key getterBlock:(AMAGetterBlock)block
{
    BOOL shouldOpen = NO;
    @synchronized (self.cacheLock) {
        shouldOpen = self.shouldDelay && self.cache[key] == nil;
    }
    if (shouldOpen) {
        @synchronized (self.dbLock) {
            // Open DB by accessing item
            block(self.storage, NULL);
        }
    }
}

- (void)applyDelayedUpdates
{
    if (self.shouldDelay == NO) {
        return;
    }
    self.shouldDelay = NO;
    [self.delayedUpdates enumerateKeysAndObjectsUsingBlock:^(NSString *key, AMASetterBlock block, BOOL *stop) {
        block(self.storage, nil);
    }];
    [self.delayedUpdates removeAllObjects];
}

- (BOOL)saveValue:(id)value forKey:(NSString *)key error:(NSError **)error setterBlock:(AMASetterBlock)block
{
    BOOL result = YES;
    @synchronized (self.cacheLock) {
        self.cache[key] = value ?: [NSNull null];
        if (self.shouldDelay) {
            self.delayedUpdates[key] = [block copy];
        }
        else {
            @synchronized (self.dbLock) {
                result = block(self.storage, error);
            }
        }
    }
    return result;
}

- (void)flush
{
    @synchronized (self.cacheLock) {
        @synchronized (self.dbLock) {
            [self applyDelayedUpdates];
        }
    }
}

#pragma mark - Cached methods

#define GET(VALUE_CLASS, GETTER) \
    return [self valueForKey:key \
                  valueClass:[VALUE_CLASS class] \
                       error:error \
                 getterBlock:^(id<AMAKeyValueStoring> storage, NSError **internalError){ \
                     return (GETTER); \
                 }];

#define SAVE(SETTER) \
    return [self saveValue:value \
                    forKey:key \
                     error:error \
               setterBlock:^BOOL(id<AMAKeyValueStoring> storage, NSError **internalError) { \
                   return (SETTER); \
               }];

- (NSNumber *)boolNumberForKey:(NSString *)key error:(NSError **)error
{
    GET(NSNumber, [storage boolNumberForKey:key error:internalError]);
}

- (BOOL)saveBoolNumber:(NSNumber *)value forKey:(NSString *)key error:(NSError **)error
{
    SAVE([storage saveBoolNumber:value forKey:key error:internalError]);
}

- (NSData *)dataForKey:(NSString *)key error:(NSError **)error
{
    GET(NSData, [storage dataForKey:key error:internalError]);
}

- (BOOL)saveData:(NSData *)value forKey:(NSString *)key error:(NSError **)error
{
    SAVE([storage saveData:value forKey:key error:internalError]);
}

- (NSDate *)dateForKey:(NSString *)key error:(NSError **)error
{
    GET(NSDate, [storage dateForKey:key error:internalError]);
}

- (BOOL)saveDate:(NSDate *)value forKey:(NSString *)key error:(NSError **)error
{
    SAVE([storage saveDate:value forKey:key error:internalError]);
}

- (NSNumber *)doubleNumberForKey:(NSString *)key error:(NSError **)error
{
    GET(NSNumber, [storage doubleNumberForKey:key error:internalError]);
}

- (BOOL)saveDoubleNumber:(NSNumber *)value forKey:(NSString *)key error:(NSError **)error
{
    SAVE([storage saveDoubleNumber:value forKey:key error:internalError]);
}

- (NSArray *)jsonArrayForKey:(NSString *)key error:(NSError **)error
{
    GET(NSArray, [storage jsonArrayForKey:key error:internalError]);
}

- (BOOL)saveJSONArray:(NSArray *)value forKey:(NSString *)key error:(NSError **)error
{
    SAVE([storage saveJSONArray:value forKey:key error:internalError]);
}

- (NSDictionary *)jsonDictionaryForKey:(NSString *)key error:(NSError **)error
{
    GET(NSDictionary, [storage jsonDictionaryForKey:key error:internalError]);
}

- (BOOL)saveJSONDictionary:(NSDictionary *)value forKey:(NSString *)key error:(NSError **)error
{
    SAVE([storage saveJSONDictionary:value forKey:key error:internalError]);
}

- (NSNumber *)longLongNumberForKey:(NSString *)key error:(NSError **)error
{
    GET(NSNumber, [storage longLongNumberForKey:key error:internalError]);
}

- (BOOL)saveLongLongNumber:(NSNumber *)value forKey:(NSString *)key error:(NSError **)error
{
    SAVE([storage saveLongLongNumber:value forKey:key error:internalError]);
}

- (NSNumber *)unsignedLongLongNumberForKey:(NSString *)key error:(NSError **)error
{
    GET(NSNumber, [storage unsignedLongLongNumberForKey:key error:internalError]);
}

- (BOOL)saveUnsignedLongLongNumber:(NSNumber *)value forKey:(NSString *)key error:(NSError **)error
{
    SAVE([storage saveUnsignedLongLongNumber:value forKey:key error:internalError]);
}

- (NSString *)stringForKey:(NSString *)key error:(NSError **)error
{
    GET(NSString, [storage stringForKey:key error:internalError]);
}

- (BOOL)saveString:(NSString *)value forKey:(NSString *)key error:(NSError **)error
{
    SAVE([storage saveString:value forKey:key error:internalError]);
}

#undef GET
#undef SAVE

@end
