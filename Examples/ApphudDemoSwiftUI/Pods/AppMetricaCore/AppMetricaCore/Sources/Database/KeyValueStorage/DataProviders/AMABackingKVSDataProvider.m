
#import "AMABackingKVSDataProvider.h"
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

@interface AMABackingKVSDataProvider ()

@property (nonatomic, copy, readonly) AMAKVSProviderSource providerSource;
@property (nonatomic, copy, readonly) AMAKVSProviderSource backingProviderSource;

@end

@implementation AMABackingKVSDataProvider

#pragma mark - Public -

- (instancetype)initWithProviderSource:(AMAKVSProviderSource)providerSource
                 backingProviderSource:(AMAKVSProviderSource)backingProviderSource
                           backingKeys:(NSArray<NSString *> *)backingKeys
{
    self = [super init];
    
    if (self != nil) {
        _providerSource = providerSource;
        _backingProviderSource = backingProviderSource;
        _backingKeys = [NSSet setWithArray:backingKeys];
    }
    
    return self;
}

#pragma mark - AMAKeyValueStorageDataProviding

- (NSArray<NSString *> *)allKeysWithError:(NSError **)error
{
    NSArray *__block result = nil;
    NSError *__block internalError = nil;
    
    self.providerSource(^(id<AMAKeyValueStorageDataProviding> underlyingProvider) {
        result = [underlyingProvider allKeysWithError:&internalError];
    });
    
    if (internalError != nil) {
        [AMAErrorUtilities fillError:error withError:internalError];
        internalError = nil;
    }
    
    if ([self.backingKeys isEqualToSet:[NSSet setWithArray:result]] == NO) {
        __weak __typeof(self) weakSelf = self;
        
        self.backingProviderSource(^(id<AMAKeyValueStorageDataProviding> underlyingProvider) {
            NSArray *localResult = [underlyingProvider allKeysWithError:&internalError];
            NSMutableSet *keys = [NSMutableSet setWithArray:localResult];
            [keys intersectSet:weakSelf.backingKeys];
            if (internalError == nil && localResult.count > 0) {
                result = [keys setByAddingObjectsFromArray:result ?: @[]].allObjects;
            }
        });
        
        if (internalError != nil) {
            [AMAErrorUtilities fillError:error withError:internalError];
        }
    }
    
    return result;
}

- (id)objectForKey:(NSString *)key error:(NSError **)error
{
    id __block result = nil;
    NSError *__block internalError = nil;
   
    self.providerSource(^(id<AMAKeyValueStorageDataProviding> underlyingProvider) {
        result = [underlyingProvider objectForKey:key error:&internalError];
    });
    
    if (internalError != nil) {
        [AMAErrorUtilities fillError:error withError:internalError];
        internalError = nil;
    }
    
    if ([self.backingKeys containsObject:key]) {
        result = [self syncKeyWithBackingDataProvider:key mainProviderResult:result error:&internalError];
        
        if (internalError != nil) {
            [AMAErrorUtilities fillError:error withError:internalError];
        }
    }
    
    return result;
}

- (NSDictionary<NSString *,id> *)objectsForKeys:(NSArray *)keys error:(NSError  **)error
{
    NSDictionary *__block result = nil;
    NSError *__block internalError = nil;
    self.providerSource(^(id<AMAKeyValueStorageDataProviding> underlyingProvider) {
        result = [underlyingProvider objectsForKeys:keys error:&internalError];
    });
    
    if (internalError != nil) {
        [AMAErrorUtilities fillError:error withError:internalError];
        internalError = nil;
    }
    
    if (self.backingKeys.count > 0) {
        NSMutableSet *backedKeys = [self.backingKeys mutableCopy];
        [backedKeys intersectSet:[NSSet setWithArray:keys]];
        
        result = [self syncKeysWithBackingDataProvider:backedKeys.allObjects
                                    mainProviderResult:result
                                                 error:&internalError];
        
        if (internalError != nil) {
            [AMAErrorUtilities fillError:error withError:internalError];
        }
    }
    
    return result;
}

- (BOOL)removeKey:(NSString *)key error:(NSError **)error
{
    BOOL __block result = NO;
    NSError *__block internalError = nil;
    
    self.providerSource(^(id<AMAKeyValueStorageDataProviding> underlyingProvider) {
        result = [underlyingProvider removeKey:key error:&internalError];
    });
    
    if (result == NO) {
        [AMAErrorUtilities fillError:error withError:internalError];
        internalError = nil;
    }
    
    if ([self.backingKeys containsObject:key]) {
        BOOL __block backingResult = NO;
        self.backingProviderSource(^(id<AMAKeyValueStorageDataProviding> underlyingProvider) {
            backingResult = [underlyingProvider removeKey:key error:&internalError];
        });
        
        if (internalError != nil) {
            AMALogError(@"%@", internalError);
        }
    }
    
    return result;
}

- (BOOL)saveObject:(id)object forKey:(NSString *)key error:(NSError **)error
{
    BOOL __block result = NO;
    NSError *__block internalError = nil;
    
    self.providerSource(^(id<AMAKeyValueStorageDataProviding> underlyingProvider) {
        result = [underlyingProvider saveObject:object forKey:key error:&internalError];
    });
    
    if (result == NO) {
        [AMAErrorUtilities fillError:error withError:internalError];
        internalError = nil;
    }
    
    if ([self.backingKeys containsObject:key]) {
        BOOL __block backingResult = NO;
        self.backingProviderSource(^(id<AMAKeyValueStorageDataProviding> underlyingProvider) {
            backingResult = [underlyingProvider saveObject:object forKey:key error:&internalError];
        });
        
        if (internalError != nil) {
            AMALogError(@"%@", internalError);
        }
    }
    
    return result;
}

- (BOOL)saveObjectsDictionary:(NSDictionary<NSString *, id> *)objectsDictionary error:(NSError **)error
{
    BOOL __block result = NO;
    NSError *__block internalError = nil;
    
    self.providerSource(^(id<AMAKeyValueStorageDataProviding> underlyingProvider) {
        result = [underlyingProvider saveObjectsDictionary:objectsDictionary error:&internalError];
    });
    
    if (result == NO) {
        [AMAErrorUtilities fillError:error withError:internalError];
        internalError = nil;
    }
    
    NSMutableSet *keys = [self.backingKeys mutableCopy];
    [keys intersectSet:[NSSet setWithArray:objectsDictionary.allKeys]];
    if (keys.count > 0) {
        NSDictionary *bakingDictionary = [AMACollectionUtilities filteredDictionary:objectsDictionary withKeys:keys];
        BOOL __block backingResult = NO;
        
        self.backingProviderSource(^(id<AMAKeyValueStorageDataProviding> underlyingProvider) {
            backingResult = [underlyingProvider saveObjectsDictionary:bakingDictionary error:&internalError];
        });
        
        if (internalError != nil) {
            AMALogError(@"%@", internalError);
        }
    }
    
    return result;
}

#pragma mark - Private -

- (id)syncKeyWithBackingDataProvider:(NSString *)key mainProviderResult:(id)mainResult error:(NSError **)error
{
    id result = nil;
    id __block backingResult = nil;
    NSError *__block internalError = nil;
    
    do {
        self.backingProviderSource(^(id<AMAKeyValueStorageDataProviding> underlyingProvider) {
            backingResult = [underlyingProvider objectForKey:key error:&internalError];
        });
        if (internalError != nil) { break; }
        
        if ([self isNull:mainResult] && [self isNull:backingResult] == NO) {
            self.providerSource(^(id<AMAKeyValueStorageDataProviding> underlyingProvider) {
                [underlyingProvider saveObject:backingResult forKey:key error:&internalError];
            });
            if (internalError != nil) { break; }
            
            result = backingResult;
        }
        else if ([self isNull:mainResult] == NO && [mainResult isEqual:backingResult] == NO) {
            self.backingProviderSource(^(id<AMAKeyValueStorageDataProviding> underlyingProvider) {
                [underlyingProvider saveObject:mainResult forKey:key error:&internalError];
            });
            if (internalError != nil) { break; }
            
            result = mainResult;
        }
        else {
            result = backingResult;
        }
        
        return result;
        
    } while (NO);
    
    if (error != NULL) {
        *error = internalError;
    }
    return result;
}

- (NSDictionary<NSString *,id> *)syncKeysWithBackingDataProvider:(NSArray<NSString *> *)keys
                                              mainProviderResult:(NSDictionary<NSString *,id> *)mainResult
                                                           error:(NSError **)error
{
    NSDictionary<NSString *,id> *__block backingResult = nil;
    NSError *__block internalError = nil;
    
    do {
        self.backingProviderSource(^(id<AMAKeyValueStorageDataProviding> underlyingProvider) {
            backingResult = [underlyingProvider objectsForKeys:keys error:&internalError];
        });
        if (internalError != nil) { break; }
                
        NSMutableDictionary *toMain = [NSMutableDictionary dictionary];
        NSMutableDictionary *toBacking = [NSMutableDictionary dictionary];
        
        NSMutableDictionary *mutableBacking = [backingResult mutableCopy];
        
        for (NSString *key in keys) {
            if ([self isNull:mainResult[key]] && [self isNull:backingResult[key]] == NO) {
                toMain[key] = backingResult[key];
            }
            else if ([self isNull:mainResult[key]] == NO && [mainResult[key] isEqual:backingResult[key]] == NO) {
                toBacking[key] = mainResult[key];
                mutableBacking[key] = nil;
            }
        }
        
        if (toMain.count > 0) {
            self.providerSource(^(id<AMAKeyValueStorageDataProviding> underlyingProvider) {
                [underlyingProvider saveObjectsDictionary:toMain error:&internalError];
            });
        }
        if (internalError != nil) { break; }
        
        if (toBacking.count > 0) {
            self.backingProviderSource(^(id<AMAKeyValueStorageDataProviding> underlyingProvider) {
                [underlyingProvider saveObjectsDictionary:toBacking error:&internalError];
            });
        }
        if (internalError != nil) { break; }

        NSMutableDictionary *mutableResult = [mainResult mutableCopy];
        [mutableResult addEntriesFromDictionary:mutableBacking];
        return [mutableResult copy];
        
    } while (NO);
    
    if (error != NULL) {
        *error = internalError;
    }
    
    return nil;
}

#pragma mark - Utility

- (BOOL)isNull:(id)obj
{
    return obj == nil || obj == NSNull.null;
}

@end
