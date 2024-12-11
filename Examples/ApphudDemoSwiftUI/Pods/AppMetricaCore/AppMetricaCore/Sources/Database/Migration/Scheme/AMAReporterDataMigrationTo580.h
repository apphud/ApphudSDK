
#import "AMADatabaseDataMigration.h"

@interface AMAReporterDataMigrationTo580 : NSObject<AMADatabaseDataMigration>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithApiKey:(NSString *)apiKey main:(BOOL)main;

@end
