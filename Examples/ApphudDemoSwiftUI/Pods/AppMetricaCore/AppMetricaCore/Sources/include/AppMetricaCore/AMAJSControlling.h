
#import <Foundation/Foundation.h>

#if !TARGET_OS_TV
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AMAAsyncExecuting;

/**
 Protocol for reporting JavaScript events to AppMetrica.
 */
NS_SWIFT_NAME(JSReporting)
@protocol AMAJSReporting <NSObject>

/**
 Reports a JavaScript event to AppMetrica.

 @param name The name of the event.
 @param value The value associated with the event.
 */
- (void)reportJSEvent:(NSString *)name value:(NSString *)value
NS_SWIFT_NAME(reportJSEvent(name:value:));

/**
 Reports a JavaScript initialization event to AppMetrica.

 @param value The value associated with the initialization event.
 */
- (void)reportJSInitEvent:(NSString *)value
NS_SWIFT_NAME(reportJSInitEvent(value:));

@end

/**
 Protocol for configuring JavaScript functionality in WKWebView.
 */
NS_SWIFT_NAME(JSControlling)
@protocol AMAJSControlling <NSObject>

/**
 The user content controller associated with the WKWebView.
 */
@property (nonatomic, strong, readonly) WKUserContentController *userContentController;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
 Sets up web view reporting with the specified executor and reporter.

 @param executor The object responsible for executing asynchronous tasks.
 @param reporter The object responsible for reporting JavaScript events to AppMetrica.
 */
- (void)setUpWebViewReporting:(id<AMAAsyncExecuting>)executor
                 withReporter:(id<AMAJSReporting>)reporter;

@end

NS_ASSUME_NONNULL_END

#endif
