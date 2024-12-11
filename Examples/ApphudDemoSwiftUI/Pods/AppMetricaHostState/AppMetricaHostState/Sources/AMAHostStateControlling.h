#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import <AppMetricaHostState/AppMetricaHostState.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AMAHostStateControlling <AMABroadcasting>

- (AMAHostAppState)hostState;

- (void)forceUpdateToForeground;

@end

@protocol AMAHostStateProviderObserver <NSObject>

- (void)hostStateProviderDidChangeHostState;

@end;

NS_ASSUME_NONNULL_END
