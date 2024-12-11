
#import "AMACore.h"
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>
#import "AMAFallbackKeychain.h"
#import "AMAKeychain.h"

@interface AMAFallbackKeychain ()

@property (nonatomic, strong, readonly) id<AMAKeyValueStoring> storage;
@property (nonatomic, strong, readonly) AMAKeychain *mainKeychain;
@property (nonatomic, strong, readonly) AMAKeychain *fallbackKeychain;

@end

@implementation AMAFallbackKeychain

- (instancetype)initWithStorage:(id<AMAKeyValueStoring>)storage
                   mainKeychain:(AMAKeychain *)mainKeychain
               fallbackKeychain:(nullable AMAKeychain *)fallbackKeychain
{
    self = [super init];
    if (self != nil) {
        _storage = storage;
        _mainKeychain = mainKeychain;
        _fallbackKeychain = fallbackKeychain;
    }
    return self;
}

+ (NSString *)wrappedKey:(NSString *)key
{
    return [NSString stringWithFormat:@"fallback-keychain-%@", key];
}

- (void)setStringValue:(NSString *)value forKey:(NSString *)key error:(NSError **)error
{
    [self.storage saveString:value forKey:[self.class wrappedKey:key] error:nil];
    
    [self.mainKeychain setStringValue:value forKey:key error:nil];
    [self.fallbackKeychain addStringValue:value forKey:key error:nil];
}

- (NSString *)stringValueForKey:(NSString *)key error:(NSError **)error
{
    NSError *dbError = nil;
    NSError *mainError = nil;
    NSError *fallbackError = nil;
    NSString *dbObject = [self.storage stringForKey:[self.class wrappedKey:key] error:&dbError];
    NSString *mainObject = [self.mainKeychain stringValueForKey:key error:&mainError];
    NSString *fallbackObject = [self.fallbackKeychain stringValueForKey:key error:&fallbackError];

    NSString *result = dbObject ?: (mainObject ?: fallbackObject);
    if (result != nil) {
        if (dbObject == nil && dbError == nil) {
            [self.storage saveString:result forKey:[self.class wrappedKey:key] error:nil];
        }
        if (mainObject == nil && mainError == nil) {
            [self.mainKeychain setStringValue:result forKey:key error:nil];
        }
        if (fallbackObject == nil && fallbackError == nil) {
            [self.fallbackKeychain addStringValue:result forKey:key error:nil];
        }
    }
    else {
        [AMAErrorUtilities fillError:error withError:(dbError ?: (mainError ?: fallbackError))];
    }

    return result;
}

@end
