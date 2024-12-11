
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(ModuleActivationConfiguration)
@interface AMAModuleActivationConfiguration : NSObject

@property (nonatomic, copy, readonly) NSString *apiKey;
@property (nonatomic, copy, nullable, readonly) NSString *appVersion;
@property (nonatomic, copy, nullable, readonly) NSString *appBuildNumber;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithApiKey:(NSString *)apiKey;
- (instancetype)initWithApiKey:(NSString *)apiKey
                    appVersion:(nullable NSString *)appVersion
                appBuildNumber:(nullable NSString *)appBuildNumber;

@end

NS_ASSUME_NONNULL_END
