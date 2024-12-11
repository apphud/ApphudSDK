
#import <Foundation/Foundation.h>

@class AMAReporterStorage;
@class AMAEnvironmentContainer;

NS_ASSUME_NONNULL_BEGIN

@interface AMAReporterStoragesContainer : NSObject

@property (nonatomic, strong, readonly) AMAEnvironmentContainer *eventEnvironment;

- (AMAReporterStorage *)mainStorageForApiKey:(NSString *)apiKey;
- (AMAReporterStorage *)storageForApiKey:(NSString *)apiKey;

- (void)completeMigrationForApiKey:(NSString *)apiKey;
- (void)waitMigrationForApiKey:(NSString *)apiKey;

+ (instancetype)sharedInstance;

@end

NS_ASSUME_NONNULL_END
