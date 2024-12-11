
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>
#import "AMAMigrationTo19FinalizationOnApiKeySpecified.h"
#import "AMADatabaseProtocol.h"
#import "AMAStorageKeys.h"
#import "AMAReporterStoragesContainer.h"
#import "AMAReporterStorage.h"
#import "AMAReporterStateStorage+Migration.h"

@implementation AMAMigrationTo19FinalizationOnApiKeySpecified

- (NSString *)migrationKey
{
    return AMAStorageStringKeyDidApplyFinalizationFor19Migration;
}

- (void)applyMigrationWithApiKey:(NSString *)apiKey toDatabase:(id<AMADatabaseProtocol>)database
{
    AMAReporterStorage *reporterStorage =
        [[AMAReporterStoragesContainer sharedInstance] storageForApiKey:apiKey];
    if (reporterStorage != nil) {
//        AMAReporterStateStorage *stateStorage = reporterStorage.stateStorage;
        [database.storageProvider inStorage:^(id<AMAKeyValueStoring> storage) {
            NSString *userInfoJSON = [storage stringForKey:@"user.info" error:nil];
            if (userInfoJSON.length != 0) {
//                [stateStorage updateUserInfoJSON:userInfoJSON];
            }
            [storage saveString:nil forKey:@"user.info" error:nil];
        }];
    }
}

@end
