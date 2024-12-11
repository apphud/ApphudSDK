
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>
#import "AMAUUIDProvider.h"
#import "AMAMetricaConfiguration.h"
#import "AMAStorageKeys.h"
#import "AMAInstantFeaturesConfiguration.h"
#import "AMADatabaseFactory.h"
#import "AMACore.h"
#import "AMAInstantFeaturesConfiguration+Migration.h"

@interface AMAUUIDProvider ()

@property (nonatomic, copy, readwrite) NSString *UUID;

@end

@implementation AMAUUIDProvider

+ (instancetype)sharedInstance
{
    static dispatch_once_t pred;
    static AMAUUIDProvider *shared = nil;
    dispatch_once(&pred, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

#pragma mark - Public -

- (NSString *)retrieveUUID
{
    if (self.UUID.length == 0) {
        @synchronized (self) {
            if (self.UUID.length == 0) {
                AMALogInfo(@"No cached uuid");

                AMAInstantFeaturesConfiguration *instantFeaturesConfiguration = [AMAInstantFeaturesConfiguration sharedInstance];
                self.UUID = instantFeaturesConfiguration.UUID;
                AMALogInfo(@"Uuid from instant features: %@", self.UUID);
                
                if (self.UUID.length > 0) {
                    return self.UUID;
                }
                
                if (self.UUID.length == 0) {
                    self.UUID = [self uuidFromOldStorage];
                    AMALogInfo(@"Uuid from old storage: %@", self.UUID);
                }
                
                if (self.UUID.length == 0) {
                    self.UUID = [self uuidFromMigrationStorage];
                    AMALogInfo(@"Uuid from old instant features: %@", self.UUID);
                }
                
                if (self.UUID.length == 0) {
                    self.UUID = [self generateUUID];
                    AMALogInfo(@"Generated uuid: %@", self.UUID);
                }
                if (self.UUID.length != 0) {
                    instantFeaturesConfiguration.UUID = self.UUID;
                } else {
                    AMALogWarn(@"Could not generate UUID");
                }
            }
        }
    }

    return self.UUID;
}

#pragma mark - Private -

- (NSString *)generateUUID
{
    unsigned char uuidData[16];
    uuid_generate(uuidData);
    NSMutableString *result = [NSMutableString stringWithCapacity:32];
    for (NSUInteger idx = 0; idx < 16; ++idx) {
        [result appendFormat:@"%02x", (unsigned int)uuidData[idx]];
    }
    return [result copy];
}

- (NSString *)uuidFromOldStorage
{
    NSString *oldUUID = nil;
    NSString *oldUUIDDatabasePath = [AMADatabaseFactory configurationDatabasePath];
    if ([AMAFileUtility fileExistsAtPath:oldUUIDDatabasePath] == YES) {
        id<AMAKeyValueStoring> uuidOldStorage = [[AMAMetricaConfiguration sharedInstance] UUIDOldStorage];
        NSError *error = nil;
        oldUUID = [uuidOldStorage stringForKey:AMAStorageStringKeyUUID error:&error];
        if (error != nil) {
            AMALogInfo(@"Failed to read uuid from old storage. Error: %@", error);
        }
    } else {
        AMALogInfo(@"No old uuid database");
    }
    return oldUUID;
}

- (NSString *)uuidFromMigrationStorage
{
    AMAInstantFeaturesConfiguration *migrationConfiguration = [AMAInstantFeaturesConfiguration migrationInstance];
    return migrationConfiguration.UUID;
}

@end
