
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AMANetworkSessionProviding;

NS_SWIFT_NAME(NetworkStrategyController)
@interface AMANetworkStrategyController : NSObject

@property (nonatomic, strong, readonly) id<AMANetworkSessionProviding> sessionProvider;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (void)registerSessionProvider:(id<AMANetworkSessionProviding>)sessionProvider;

+ (instancetype)sharedInstance;

@end

NS_ASSUME_NONNULL_END
