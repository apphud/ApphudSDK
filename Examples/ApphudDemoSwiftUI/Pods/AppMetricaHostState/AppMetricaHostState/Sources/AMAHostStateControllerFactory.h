
#import <Foundation/Foundation.h>

@protocol AMAHostStateControlling;

@interface AMAHostStateControllerFactory : NSObject

- (instancetype)initWithBundle:(NSBundle *)bundle;

- (id<AMAHostStateControlling>)hostStateController;

@end
