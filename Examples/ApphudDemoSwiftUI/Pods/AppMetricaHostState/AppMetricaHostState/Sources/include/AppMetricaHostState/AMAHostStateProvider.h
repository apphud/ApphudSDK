#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AMAHostAppState) {
    AMAHostAppStateForeground = 0,
    AMAHostAppStateBackground = 1,
    AMAHostAppStateTerminated = 2,
    AMAHostAppStateUnknown = -1,
} NS_SWIFT_NAME(HostAppState);

NS_SWIFT_NAME(HostStateProviderDelegate)
@protocol AMAHostStateProviderDelegate <NSObject>

- (void)hostStateDidChange:(AMAHostAppState)hostState;

@end

NS_SWIFT_NAME(HostStateProviding)
@protocol AMAHostStateProviding <NSObject>

@property (nonatomic, nullable, weak) id<AMAHostStateProviderDelegate> delegate;

- (AMAHostAppState)hostState;

- (void)forceUpdateToForeground;

@end

NS_SWIFT_NAME(HostStateProvider)
@interface AMAHostStateProvider : NSObject<AMAHostStateProviding>

@end

NS_ASSUME_NONNULL_END
