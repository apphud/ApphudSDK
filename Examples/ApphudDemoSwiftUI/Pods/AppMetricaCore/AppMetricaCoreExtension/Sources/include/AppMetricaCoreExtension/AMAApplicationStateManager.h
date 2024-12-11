
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class AMAApplicationState;

NS_SWIFT_NAME(ApplicationStateManager)
@interface AMAApplicationStateManager : NSObject

@property (class, readonly) AMAApplicationState *applicationState;
@property (class, readonly) AMAApplicationState *quickApplicationState;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (AMAApplicationState *)stateWithFilledEmptyValues:(AMAApplicationState *)appState;

@end

NS_ASSUME_NONNULL_END

