
#import "AMACore.h"
#import "AMAJSONFileKVSDataProvider.h"
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

@interface AMAJSONFileKVSDataProvider ()

@property (nonatomic, strong, readonly) id<AMAFileStorage> fileStorage;

@property (nonatomic, strong) NSMutableDictionary *cachedDictionary;

@end

@implementation AMAJSONFileKVSDataProvider

@synthesize cachedDictionary = _cachedDictionary;

- (instancetype)initWithFileStorage:(id<AMAFileStorage>)fileStorage
{
    self = [super init];
    if (self != nil) {
        _fileStorage = fileStorage;
    }
    return self;
}

- (BOOL)ensureDictionaryLoadedWithError:(NSError **)error
{
    if (self.cachedDictionary != nil) {
        return YES;
    }
    self.cachedDictionary = [[self loadDictionaryWithError:error] mutableCopy];
    return self.cachedDictionary != nil;
}

- (BOOL)updateObject:(id)object forKey:(NSString *)key
{
    if (object == [NSNull null]) {
        object = nil;
    }
    
    id existingObject = self.cachedDictionary[key];
    if (existingObject == object || [existingObject isEqual:object]) {
        return NO;
    }

    self.cachedDictionary[key] = object;
    return YES;
}

#pragma mark - Persistence

- (NSDictionary *)loadDictionaryWithError:(NSError **)error
{
    NSError *internalError = nil;

    if (self.fileStorage.fileExists == NO) {
        AMALogInfo(@"File is not exists: %@. Assuming empty dictionary.", self.fileStorage);
        return @{};
    }

    NSData *data = [self.fileStorage readDataWithError:&internalError];
    if (data == nil) {
        AMALogError(@"Failed to read data of file: %@", internalError);
        [AMAErrorUtilities fillError:error withError:internalError];
        return nil;
    }

    NSDictionary *dictionary = [AMAJSONSerialization dictionaryWithJSONData:data error:&internalError];
    if (dictionary == nil) {
        AMALogError(@"Failed to deserialize JSON: %@", internalError);
        [AMAErrorUtilities fillError:error withError:internalError];
        return nil;
    }

    return dictionary;
}

- (BOOL)saveDictionary:(NSDictionary *)dictionary withError:(NSError **)error
{
    NSError *internalError = nil;

    NSData *data = [AMAJSONSerialization dataWithJSONObject:dictionary error:&internalError];
    if (data == nil) {
        AMALogError(@"Failed to serialize object into JSON: %@", internalError);
        [AMAErrorUtilities fillError:error withError:internalError];
        return NO;
    }

    BOOL result = [self.fileStorage writeData:data error:&internalError];
    if (result == NO) {
        AMALogError(@"Failed to write data to file: %@", internalError);
        [AMAErrorUtilities fillError:error withError:internalError];
        return NO;
    }

    return result;
}

#pragma mark - AMAKeyValueStorageDataProviding

- (BOOL)removeKey:(NSString *)key error:(NSError **)error
{
    return [self saveObject:nil forKey:key error:error];
}

- (id)objectForKey:(NSString *)key error:(NSError **)error
{
    @synchronized (self) {
        if ([self ensureDictionaryLoadedWithError:error] == NO) {
            return nil;
        }
        return self.cachedDictionary[key];
    }
}

- (BOOL)saveObject:(id)object forKey:(NSString *)key error:(NSError **)error
{
    @synchronized (self) {
        if ([self ensureDictionaryLoadedWithError:error] == NO) {
            return NO;
        }

        if ([self updateObject:object forKey:key]) {
            return [self saveDictionary:self.cachedDictionary withError:error];
        }
        else {
            return YES;
        }
    }
}

- (NSArray<NSString *> *)allKeysWithError:(NSError **)error
{
    @synchronized (self) {
        if ([self ensureDictionaryLoadedWithError:error] == NO) {
            return nil;
        }

        return self.cachedDictionary.allKeys;
    }
}

- (NSDictionary<NSString *,id> *)objectsForKeys:(NSArray *)keys error:(NSError **)error
{
    @synchronized (self) {
        if ([self ensureDictionaryLoadedWithError:error] == NO) {
            return nil;
        }

        return [AMACollectionUtilities filteredDictionary:self.cachedDictionary
                                                 withKeys:[NSSet setWithArray:keys]];
    }
}

- (BOOL)saveObjectsDictionary:(NSDictionary<NSString *,id> *)objectsDictionary error:(NSError **)error
{
    @synchronized (self) {
        if ([self ensureDictionaryLoadedWithError:error] == NO) {
            return NO;
        }

        BOOL __block updated = NO;
        [objectsDictionary enumerateKeysAndObjectsUsingBlock:^(NSString *key, id object, BOOL *stop) {
            updated = [self updateObject:object forKey:key];
        }];

        return updated ? [self saveDictionary:self.cachedDictionary withError:error] : YES;
    }
}

@end
