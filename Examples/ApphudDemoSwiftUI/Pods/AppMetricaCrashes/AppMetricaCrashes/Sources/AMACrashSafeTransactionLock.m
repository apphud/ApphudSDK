#import "AMACrashSafeTransactionLock.h"
#import "AMABuildUID.h"
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

static NSString *const kAMATransactionBuildUIDKey = @"buildUID";
static NSString *const kAMATransactionNameKey = @"name";
static NSString *const kAMATransactionRollbackContextKey = @"rollbackContext";
static NSString *const kAMATransactionShouldBeReportedKey = @"shouldBeReported";
static NSString *const kAMATransactionRollbackLockedKey = @"rollbackLocked";

@interface AMACrashSafeTransactionLock ()

@property (nonatomic, copy) NSDictionary *dictionary;
@property (nonatomic, copy, readonly) NSString *transactionName;
@property (nonatomic, copy, readonly) NSString *transactionKey;
@property (nonatomic, copy, readonly) NSString *currentBuildUID;

@end

@implementation AMACrashSafeTransactionLock
@dynamic rollbackContext;

- (instancetype)initWithTransactionID:(NSString *)transactionID name:(NSString *)name
{
    return [self initWithTransactionID:transactionID name:name rollbackContext:nil];
}

- (instancetype)initWithTransactionID:(NSString *)transactionID
                                 name:(NSString *)name
                      rollbackContext:(id<NSCoding>)rollbackContext
{
    self = [super init];
    if (self != nil) {

        _transactionName = [name copy] ?: @"Unknown";
        _transactionKey = [NSString stringWithFormat:@"AMATransaction:%@%@", transactionID, self.transactionName];
        _currentBuildUID = AMABuildUID.buildUID.stringValue ?: @"";

        if (self.dictionary == nil) {
            NSMutableDictionary *dictionary = [@{
                   kAMATransactionBuildUIDKey: self.currentBuildUID,
                   kAMATransactionNameKey: self.transactionName,
                   kAMATransactionShouldBeReportedKey: @YES,
                   kAMATransactionRollbackLockedKey: @NO
                } mutableCopy];

            if (rollbackContext != nil) {
                NSData *rollbackContextData =
                    [NSKeyedArchiver archivedDataWithRootObject:rollbackContext
                                          requiringSecureCoding:NO
                                                          error:NULL];

                [dictionary setObject:rollbackContextData
                               forKey:kAMATransactionRollbackContextKey];
            }

            self.dictionary = dictionary;
        }
    }

    return self;
}

- (NSDictionary *)lockedDictionary
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:self.transactionKey];
}

- (void)lockDictionary:(NSDictionary *)dictionary
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    [defaults setObject:dictionary forKey:self.transactionKey];
    [defaults synchronize];
}

- (NSDictionary *)dictionary
{
    NSDictionary *lockedDictionary = [self lockedDictionary];

    if (lockedDictionary != nil) {
        self.dictionary = lockedDictionary;
    }

    return _dictionary;
}

- (NSString *)lockOwnerName
{
    return self.dictionary[kAMATransactionNameKey];
}

- (id)rollbackContext
{
    id rollbackContext = nil;
    NSData *rollbackContextData = self.dictionary[kAMATransactionRollbackContextKey];
    
    if (rollbackContextData != nil) {
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:rollbackContextData 
                                                                                    error:NULL];
        unarchiver.requiresSecureCoding = NO;
        rollbackContext = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
    }

    return rollbackContext;
}

- (BOOL)transactionLocked
{
    return [[self lockedDictionary][kAMATransactionBuildUIDKey] isEqual:self.currentBuildUID];
}

- (void)lockTransaction
{
    if (self.transactionLocked == NO) {
        [self lockDictionary:self.dictionary];
    }
}

- (void)releaseTransaction
{
    [self lockDictionary:nil];
}

- (BOOL)rollbackLocked
{
    return [self transactionFlagWithKey:kAMATransactionRollbackLockedKey];
}

- (void)setRollbackLocked:(BOOL)rollbackLocked
{
    [self setTransactionFlag:rollbackLocked forKey:kAMATransactionRollbackLockedKey];
}

- (BOOL)shouldBeReported
{
    return [self transactionFlagWithKey:kAMATransactionShouldBeReportedKey];
}

- (void)setShouldBeReported:(BOOL)shouldBeReported
{
    [self setTransactionFlag:shouldBeReported forKey:kAMATransactionShouldBeReportedKey];
}

- (BOOL)transactionFlagWithKey:(nonnull NSString *)key
{
    return [self.dictionary[key] boolValue];
}

- (void)setTransactionFlag:(BOOL)flag forKey:(nonnull NSString *)key
{
    NSMutableDictionary *dictionary = [self.dictionary mutableCopy];
    dictionary[key] = @(flag);

    if ([self transactionLocked]) {
        [self lockDictionary:dictionary];
    }
}

@end
