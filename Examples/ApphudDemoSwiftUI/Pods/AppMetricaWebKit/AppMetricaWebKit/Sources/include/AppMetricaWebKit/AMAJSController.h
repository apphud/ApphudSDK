
#import <Foundation/Foundation.h>

#if !TARGET_OS_TV
#import <AppMetricaCore/AppMetricaCore.h>
#import <WebKit/WKScriptMessageHandler.h>

NS_ASSUME_NONNULL_BEGIN

API_UNAVAILABLE(tvos)
NS_SWIFT_NAME(JSController)
@interface AMAJSController : NSObject<AMAJSControlling, WKScriptMessageHandler>

- (instancetype)initWithUserContentController:(WKUserContentController *)userContentController;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

#endif // !TARGET_OS_TV
