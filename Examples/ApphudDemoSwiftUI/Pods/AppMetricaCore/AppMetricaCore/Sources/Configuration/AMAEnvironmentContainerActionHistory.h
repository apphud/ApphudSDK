
#import <Foundation/Foundation.h>

@class AMAEnvironmentContainer;

NS_ASSUME_NONNULL_BEGIN

@interface AMAEnvironmentContainerActionHistory : NSObject

- (void)trackAddValue:(nullable NSString *)value forKey:(NSString *)key;
- (void)trackClearEnvironment;

- (NSArray *)trackedActions;

@end

NS_ASSUME_NONNULL_END
