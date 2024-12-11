
#import <AppMetricaNetwork/AppMetricaNetwork.h>

@class AMAReportPayload;

@interface AMAReportRequest : AMAGenericRequest

@property (nonatomic) AMARequestParametersOptions requestParametersOptions;
@property (nonatomic, strong, readonly) AMAReportPayload *reportPayload;
@property (nonatomic, copy, readonly) NSString *requestIdentifier;

+ (instancetype)reportRequestWithPayload:(AMAReportPayload *)reportPayload
                       requestIdentifier:(NSString *)requestIdentifier
                requestParametersOptions:(AMARequestParametersOptions)requestParametersOptions;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end
