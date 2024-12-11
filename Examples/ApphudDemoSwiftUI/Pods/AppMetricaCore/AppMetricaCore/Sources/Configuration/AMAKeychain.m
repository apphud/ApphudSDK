
#import "AMACore.h"
#import "AMAKeychain.h"
#import "AMAKeychainQueryBuilder.h"
#import "AMAKeychainBridge.h"

NSString *const kAMAKeychainErrorDomain = @"kAMAKeychainErrorDomain";
NSString *const kAMAKeychainErrorKeyCode = @"kAMAKeychainErrorKeyCode";

static NSString *const AMAKeychainAvailabilityCheckObjectKey = @"AMAKeychainAvailabilityCheckObjectKey";
static NSString *const AMAKeychainAvailabilityCheckObject = @"AMAKeychainAvailabilityCheckObject";

@interface AMAKeychain ()

@property (nonatomic, strong) AMAKeychainQueryBuilder *queryBuilder;
@property (nonatomic, strong) AMAKeychainBridge *bridge;

@end

@implementation AMAKeychain

- (instancetype)initWithService:(NSString *)service
{
    return [self initWithService:service accessGroup:@""];
}

- (nullable instancetype)initWithService:(NSString *)service accessGroup:(NSString *)accessGroup
{
    return [self initWithService:service accessGroup:accessGroup bridge:[[AMAKeychainBridge alloc] init]];
}

- (instancetype)initWithService:(NSString *)service accessGroup:(NSString *)accessGroup bridge:(AMAKeychainBridge *)bridge
{
    NSParameterAssert(service.length);
    if (service.length == 0) {
        return nil;
    }

    self = [super init];
    if (self != nil) {
        NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithDictionary:@{
                (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
                (__bridge id)kSecAttrAccessible : (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                (__bridge id)kSecAttrService : service,
        }];

        // Apps that are built for the simulator aren't signed, so there's no keychain access group
        // for the simulator to check. This means that all apps can see all keychain items when run
        // on the simulator.
#if !TARGET_IPHONE_SIMULATOR
        if (accessGroup.length != 0) {
            parameters[(__bridge id)kSecAttrAccessGroup] = accessGroup;
        }
#endif

        _bridge = bridge;
        _queryBuilder = [[AMAKeychainQueryBuilder alloc] initWithQueryParameters:parameters];
    }
    return self;
}

- (void)resetKeychain
{
    NSDictionary *entriesQuery = [self.queryBuilder entriesQuery];
    if (entriesQuery == nil) {
        return;
    }

    [self.bridge deleteEntryWithQuery:entriesQuery];
}

- (BOOL)isAvailable
{
    NSError *error = nil;
    NSString *savedValue = nil;

    [self setStringValue:AMAKeychainAvailabilityCheckObject forKey:AMAKeychainAvailabilityCheckObjectKey error:&error];
    if (error == nil) {
        savedValue = [self stringValueForKey:AMAKeychainAvailabilityCheckObjectKey error:&error];
        [self removeStringValueForKey:AMAKeychainAvailabilityCheckObjectKey error:nil];
    }

    return error == nil && [savedValue isEqual:AMAKeychainAvailabilityCheckObject];
}

- (void)setStringValue:(NSString *)value forKey:(NSString *)key error:(NSError **)error
{
    if (value == nil) {
        return;
    }

    NSError *archiveError = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:value requiringSecureCoding:YES error:&archiveError];
    if (archiveError) {
        AMALogError(@"Error archiving data: %@", archiveError);
        [self fillError:error withErrorCode:kAMAKeychainErrorCodeDecode statusCode:0 underlyingError:archiveError];
    }

    if ([self dataForKey:key error:nil] == nil) {
        [self addData:data forKey:key error:error];
    }
    else {
        [self updateData:data forKey:key error:error];
    }
}

- (void)addStringValue:(NSString *)value forKey:(NSString *)key error:(NSError **)error
{
    if (value == nil) {
        return;
    }

    NSError *archiveError = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:value requiringSecureCoding:YES error:&archiveError];
    if (archiveError) {
        AMALogError(@"Error archiving data: %@", archiveError);
        [self fillError:error withErrorCode:kAMAKeychainErrorCodeDecode statusCode:0 underlyingError:archiveError];
    }

    if ([self dataForKey:key error:nil] == nil) {
        [self addData:data forKey:key error:error];
    }
}

- (void)updateData:(NSData *)data forKey:(NSString *)key error:(NSError **)error
{
    NSDictionary *updateQuery = [self.queryBuilder updateEntryQueryWithData:data];
    NSDictionary *entryQuery = [self.queryBuilder entryQueryForKey:key];
    if (updateQuery == nil || entryQuery == nil) {
        [self fillError:error wtithErrorCode:kAMAKeychainErrorCodeQueryCreation];
        return;
    }

    OSStatus result = [self.bridge updateEntryWithQuery:entryQuery attributesToUpdate:updateQuery];
    if (result != noErr) {
        AMALogError(@"Failed to update object for key %@ with osstatus %ld", key, (long)result);
        [self fillError:error withErrorCode:kAMAKeychainErrorCodeUpdate statusCode:result];
    }
}

- (void)addData:(NSData *)data forKey:(NSString *)key error:(NSError **)error
{
    NSDictionary *dataQuery = [self.queryBuilder addEntryQueryWithData:data forKey:key];
    if (dataQuery == nil) {
        return;
    }

    OSStatus result = [self.bridge addEntryWithAttributes:dataQuery];
    if (result != noErr) {
        AMALogError(@"Failed to add object for key %@ with osstatus %ld", key, (long)result);
        [self fillError:error withErrorCode:kAMAKeychainErrorCodeAdd statusCode:result];
    }
}

- (NSString *)stringValueForKey:(NSString *)key error:(NSError **)error
{
    NSData *data = [self dataForKey:key error:error];
    if (data == nil) {
        return nil;
    }

    NSString *value = nil;
    NSError *unarchiveError = nil;
    value = [NSKeyedUnarchiver unarchivedObjectOfClass:NSString.class fromData:data error:&unarchiveError];
    if (unarchiveError != nil) {
        AMALogError(@"Error unarchiving data: %@", unarchiveError);
        [self fillError:error withErrorCode:kAMAKeychainErrorCodeDecode statusCode:0 underlyingError:unarchiveError];
    }
    return value;
}

- (nullable NSData *)dataForKey:(NSString *)key error:(NSError **)error
{
    NSDictionary *dataQuery = [self.queryBuilder dataQueryForKey:key];
    if (dataQuery == nil) {
        return nil;
    }

    NSData *data = nil;
    OSStatus result = [self.bridge copyMatchingEntryWithQuery:dataQuery resultData:&data];
    if (result != noErr && result != errSecItemNotFound) {
        AMALogError(@"Failed to retrieve data for key %@, osstatus %ld", key, (long)result);
        [self fillError:error withErrorCode:kAMAKeychainErrorCodeGet statusCode:result];
    }

    return data;
}

- (void)removeStringValueForKey:(id)key error:(NSError **)error
{
    if ([self dataForKey:key error:nil] == nil) {
        return;
    }
    
    NSDictionary *entryQuery = [self.queryBuilder entryQueryForKey:key];
    if (entryQuery == nil) {
        [self fillError:error wtithErrorCode:kAMAKeychainErrorCodeQueryCreation];
        return;
    }
    
    OSStatus result = [self.bridge deleteEntryWithQuery:entryQuery];
    if (result != noErr && result != errSecItemNotFound) {
        AMALogError(@"Failed to delete data for key %@, osstatus %ld", key, (long)result);
        [self fillError:error withErrorCode:kAMAKeychainErrorCodeRemove statusCode:result];
    }
}

- (void)fillError:(NSError **)error wtithErrorCode:(kAMAKeychainErrorCode)errorCode
{
    [self fillError:error withErrorCode:errorCode statusCode:0 underlyingError:nil];
}

- (void)fillError:(NSError **)error withErrorCode:(kAMAKeychainErrorCode)errorCode statusCode:(OSStatus)status
{
    [self fillError:error withErrorCode:errorCode statusCode:status underlyingError:nil];
}

- (void)fillError:(NSError **)error 
    withErrorCode:(kAMAKeychainErrorCode)errorCode
       statusCode:(OSStatus)status
  underlyingError:(NSError *)underlyingError
{
    NSMutableDictionary *userInfo = NSMutableDictionary.dictionary;
    userInfo[kAMAKeychainErrorKeyCode] = @(status);
    userInfo[NSUnderlyingErrorKey] = underlyingError;
    
    NSError *internalError = [NSError errorWithDomain:kAMAKeychainErrorDomain
                                                 code:errorCode
                                             userInfo:userInfo];
    [AMAErrorUtilities fillError:error withError:internalError];
}


@end
