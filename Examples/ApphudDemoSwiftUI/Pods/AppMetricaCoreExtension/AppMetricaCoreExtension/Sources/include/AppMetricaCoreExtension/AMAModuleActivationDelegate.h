
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class AMAModuleActivationConfiguration;

NS_SWIFT_NAME(ModuleActivationDelegate)
@protocol AMAModuleActivationDelegate <NSObject>

+ (void)willActivateWithConfiguration:(AMAModuleActivationConfiguration *)configuration;
+ (void)didActivateWithConfiguration:(AMAModuleActivationConfiguration *)configuration;

@end

NS_ASSUME_NONNULL_END
