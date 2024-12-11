
#import "AMACore.h"
#import "AMAReporterStoragesContainer.h"
#import "AMAReporterStorage.h"
#import "AMAMetricaConfiguration.h"

@interface AMAReporterStoragesContainer ()

@property (nonatomic, strong, readonly) NSCondition *storageCondition;
@property (nonatomic, strong, readonly) id<AMAAsyncExecuting> executor;
@property (nonatomic, strong, readonly) NSMutableDictionary *storages;
@property (nonatomic, strong, readwrite) AMAReporterStorage *mainReporterStorage;
@property (nonatomic, strong, readonly) NSMutableSet *migratedKeys;
@property (nonatomic, assign) BOOL migrated;
@property (nonatomic, assign) BOOL forcedMigration;

@end

@implementation AMAReporterStoragesContainer

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _eventEnvironment = [[AMAEnvironmentContainer alloc] init];
        _storageCondition = [[NSCondition alloc] init];
        _executor = [[AMAExecutor alloc] initWithIdentifier:self];
        _storages = [NSMutableDictionary dictionary];
        _migratedKeys = [NSMutableSet set];
        _migrated = NO;
        _mainReporterStorage = nil;
    }
    return self;
}

- (AMAReporterStorage *)mainStorageForApiKey:(NSString *)apiKey
{
    AMAReporterStorage *reporterStorage = self.mainReporterStorage;
    if (reporterStorage == nil) {
        reporterStorage = [[AMAReporterStorage alloc] initWithApiKey:apiKey
                                                    eventEnvironment:self.eventEnvironment
                                                                main:YES];
        self.mainReporterStorage = reporterStorage;
    }
    else if ([reporterStorage.apiKey isEqual:apiKey] == NO) {
        [reporterStorage updateAPIKey:apiKey];
    }
    return reporterStorage;
}

- (AMAReporterStorage *)storageForApiKey:(NSString *)apiKey
{
    [self.storageCondition lock];
    if (self.mainReporterStorage && [self.mainReporterStorage.apiKey isEqual:apiKey]) {
        [self.storageCondition unlock];
        return self.mainReporterStorage;
    }
    AMAReporterStorage *storage = self.storages[apiKey];
    if (storage == nil) {
        storage = [[AMAReporterStorage alloc] initWithApiKey:apiKey
                                            eventEnvironment:self.eventEnvironment
                                                        main:NO];
        self.storages[apiKey] = storage;
    }
    [self.storageCondition unlock];
    return storage;
}

- (void)completeMigrationForApiKey:(NSString *)apiKey
{
    if (self.migrated) {
        AMALogAssert(@"Somebody did complete migration for %@, but over all migration is already complete.", apiKey);
        return;
    }
    [self.storageCondition lock];
    [self.migratedKeys addObject:apiKey];
    [self.storageCondition broadcast];
    [self.storageCondition unlock];
}

- (void)waitMigrationForApiKey:(NSString *)apiKey
{
    if (self.migrated) {
        return;
    }
    [self forceMigration];
    [self.storageCondition lock];
    while (self.migrated == NO && [self.migratedKeys containsObject:apiKey] == NO) {
        [self.storageCondition wait];
    }
    [self.storageCondition unlock];
}

- (void)forceMigration
{
    if (self.forcedMigration == NO) {
        [self.executor execute:^{
            if (self.forcedMigration == NO) {
                self.forcedMigration = YES;
                [[AMAMetricaConfiguration sharedInstance] ensureMigrated];
                [self completeAllMigrations];
            }
        }];
    }
}

- (void)completeAllMigrations
{
    if (self.migrated) {
        return;
    }
    [self.storageCondition lock];
    self.migrated = YES;
    [self.storageCondition broadcast];
    [self.storageCondition unlock];
}

+ (instancetype)sharedInstance
{
    static AMAReporterStoragesContainer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AMAReporterStoragesContainer alloc] init];
    });
    return instance;
}

@end
