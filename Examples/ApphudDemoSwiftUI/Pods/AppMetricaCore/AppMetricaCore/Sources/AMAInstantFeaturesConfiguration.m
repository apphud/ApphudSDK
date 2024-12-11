
#import "AMAInstantFeaturesConfiguration.h"
#import "AMAStorageKeys.h"
#import "AMAStartupParametersConfiguration.h"
#import "AMAJSONFileKVSDataProvider.h"
#import "AMACore.h"
#import "AMAMigrationTo500Utils.h"

NSString *const kAMAInstantFileName = @"instant.json";

@interface AMAInstantFeaturesConfiguration ()

@property (nonatomic, strong, readonly) AMAJSONFileKVSDataProvider *backingFileStorage;
@property (nonatomic, strong, readonly) NSHashTable *observersTable;

@end

@implementation AMAInstantFeaturesConfiguration

+ (instancetype)sharedInstance
{
    static dispatch_once_t pred;
    static AMAInstantFeaturesConfiguration *shared = nil;
    dispatch_once(&pred, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (instancetype)init
{
    NSString *filePath = [AMAFileUtility.persistentPath stringByAppendingPathComponent:kAMAInstantFileName];
    return [self initWithFilePath:filePath];
}

- (instancetype)initWithJSONDataProvider:(AMAJSONFileKVSDataProvider *)provider
{
    self = [super init];
    if (self != nil) {
        _backingFileStorage = provider;
        _observersTable = [NSHashTable weakObjectsHashTable];
    }
    return self;
}

#pragma mark - Public -

- (void)setUUID:(NSString *)value
{
    NSString *uuid = [self.backingFileStorage objectForKey:AMAStorageStringKeyUUID error:NULL];
    if (uuid.length == 0) {
        [self.backingFileStorage saveObject:value.copy forKey:AMAStorageStringKeyUUID error:NULL];
    }
}

- (NSString *)UUID
{
    return [self.backingFileStorage objectForKey:AMAStorageStringKeyUUID error:NULL];
}

#pragma mark - Migration -

+ (instancetype)migrationInstance
{
    NSString *filePath = [[AMAMigrationTo500Utils migrationPath] stringByAppendingPathComponent:kAMAInstantFileName];
    return [[self alloc] initWithFilePath:filePath];
}

- (instancetype)initWithFilePath:(NSString *)filePath
{
    AMADiskFileStorageOptions options = AMADiskFileStorageOptionNoBackup | AMADiskFileStorageOptionCreateDirectory;
    AMADiskFileStorage *fileStorage = [[AMADiskFileStorage alloc] initWithPath:filePath options:options];
    return [self initWithJSONDataProvider:[[AMAJSONFileKVSDataProvider alloc] initWithFileStorage:fileStorage]];
}

@end
