
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

@class AMAApplicationState;

typedef NS_OPTIONS(int, AMARequestParametersOptions) {
    AMARequestParametersNone = 0,
    AMARequestParametersAllowIDFA = 1 << 0,

    AMARequestParametersDefault = 0,
    AMARequestParametersTracking = AMARequestParametersAllowIDFA,
} NS_SWIFT_NAME(RequestParametersOptions);

NS_SWIFT_NAME(RequestParameters)
@interface AMARequestParameters : NSObject <AMADictionaryRepresentation>

@property (nonatomic, readonly) AMARequestParametersOptions options;

- (instancetype)initWithApiKey:(NSString *)apiKey
                 attributionID:(NSString *)attributionID
                     requestID:(NSString *)requestID
              applicationState:(AMAApplicationState *)appState
              inMemoryDatabase:(BOOL)inMemoryDatabase
                       options:(AMARequestParametersOptions)options;

@end
