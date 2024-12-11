
#import <Foundation/Foundation.h>
#import "AMAPersistentTimeoutConfiguration.h"

@protocol AMAResettableIterable;
@protocol AMADateProviding;

@interface AMATimeoutRequestsController : NSObject

@property (nonatomic, strong, readonly) AMAPersistentTimeoutConfiguration *configuration;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithHostType:(AMAHostType)hostType configuration:(AMAPersistentTimeoutConfiguration *)configuration;

- (instancetype)initWithHostType:(AMAHostType)hostType
                   configuration:(AMAPersistentTimeoutConfiguration *)configuration
                    dateProvider:(id<AMADateProviding>)dateProvider NS_DESIGNATED_INITIALIZER;

- (BOOL)isAllowed;
- (void)reportOfSuccess;
- (void)reportOfFailure;

@end
