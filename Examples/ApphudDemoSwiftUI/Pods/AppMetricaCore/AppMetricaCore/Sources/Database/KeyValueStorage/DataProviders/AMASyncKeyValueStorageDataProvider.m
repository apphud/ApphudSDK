
#import "AMASyncKeyValueStorageDataProvider.h"
#import "AMADatabaseProtocol.h"

@interface AMASyncKeyValueStorageDataProvider ()

@property (nonatomic, copy, readonly) AMAKVSProviderSource providerSource;

@end

@implementation AMASyncKeyValueStorageDataProvider

- (instancetype)initWithUnderlyingProviderSource:(AMAKVSProviderSource)providerSource
{
    self = [super init];
    if (self != nil) {
        _providerSource = providerSource;
    }
    return self;
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
    }
    return result;
}

- (NSArray<NSString *> *)allKeysWithError:(NSError **)error
{
    NSArray *__block result = nil;
    NSError *__block internalError = nil;
    self.providerSource(^(id<AMAKeyValueStorageDataProviding> underlyingProvider) {
        result = [underlyingProvider allKeysWithError:&internalError];
    });
    if (internalError != nil) {
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return result;
}

- (NSDictionary<NSString *, id> *)objectsForKeys:(NSArray *)keys error:(NSError **)error
{
    NSDictionary *__block result = nil;
    NSError *__block internalError = nil;
    self.providerSource(^(id<AMAKeyValueStorageDataProviding> underlyingProvider) {
        result = [underlyingProvider objectsForKeys:keys error:&internalError];
    });
    if (internalError != nil) {
        [AMAErrorUtilities fillError:error withError:internalError];
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
    }
    return result;
}

@end
