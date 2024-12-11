
#import <Foundation/Foundation.h>

@class AMAReportRequestModel;
@class AMAReportPayload;
@class AMAReportPayloadProvider;
@class AMAEvent;

extern NSString *const kAMAReportPayloadProviderErrorDomain;

typedef NS_ENUM(NSInteger, AMAReportPayloadProviderErrorCode) {
    AMAReportPayloadProviderErrorOther,
    AMAReportPayloadProviderErrorAllSessionsAreEmpty,
    AMAReportPayloadProviderErrorEncryption,
};

@protocol AMAReportPayloadProviderDelegate <NSObject>

- (void)reportPayloadProvider:(AMAReportPayloadProvider *)provider didFailedToReadFileOfEvent:(AMAEvent *)event;

@end

@interface AMAReportPayloadProvider : NSObject

@property (nonatomic, weak) id<AMAReportPayloadProviderDelegate> delegate;

- (AMAReportPayload *)generatePayloadWithRequestModel:(AMAReportRequestModel *)requestModel error:(NSError **)error;

@end

