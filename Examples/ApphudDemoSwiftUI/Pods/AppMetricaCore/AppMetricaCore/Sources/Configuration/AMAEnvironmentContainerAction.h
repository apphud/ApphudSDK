
#import <Foundation/Foundation.h>

@class AMAEnvironmentContainer;

NS_ASSUME_NONNULL_BEGIN

@protocol AMAEnvironmentContainerAction <NSObject>

- (void)applyToContainer:(AMAEnvironmentContainer *)container;

@end

@interface AMAEnvironmentContainerAddValueAction : NSObject<AMAEnvironmentContainerAction>

@property (nonatomic, copy, readonly) NSString *key;
@property (nonatomic, copy, readonly, nullable) NSString *value;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithValue:(nullable NSString *)value forKey:(NSString *)key NS_DESIGNATED_INITIALIZER;

@end

@interface AMAEnvironmentContainerClearAction : NSObject<AMAEnvironmentContainerAction>

@end

NS_ASSUME_NONNULL_END
