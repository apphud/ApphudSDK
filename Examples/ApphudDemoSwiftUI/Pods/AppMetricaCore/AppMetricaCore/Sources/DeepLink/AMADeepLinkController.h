
#import <Foundation/Foundation.h>

@protocol AMAAsyncExecuting;
@class AMAReporter;

extern NSString *const kAMADLControllerUrlTypeOpen;

@interface AMADeepLinkController : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithReporter:(AMAReporter *)reporter
                        executor:(id<AMAAsyncExecuting>)executor NS_DESIGNATED_INITIALIZER;

- (void)reportUrl:(NSURL *)url ofType:(NSString *)type isAuto:(BOOL)isAuto;

@end
