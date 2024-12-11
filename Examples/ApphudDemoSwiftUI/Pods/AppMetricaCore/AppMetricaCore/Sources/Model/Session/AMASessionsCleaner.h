
#import <Foundation/Foundation.h>
#import "AMAEventsCleanupReasonType.h"

@class AMAReportRequestModel;
@class AMAReportEventsBatch;
@class AMAEventsCleaner;
@protocol AMADatabaseProtocol;

@interface AMASessionsCleaner : NSObject

@property (nonatomic, strong, readonly) AMAEventsCleaner *eventsCleaner;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithDatabase:(id<AMADatabaseProtocol>)database
                   eventsCleaner:(AMAEventsCleaner *)eventsCleaner
                          apiKey:(NSString *)apiKey;

- (void)purgeSessionWithRequestModel:(AMAReportRequestModel *)requestModel
                              reason:(AMAEventsCleanupReasonType)reasonType;

- (void)purgeSessionWithEventsBatches:(NSArray <AMAReportEventsBatch *> *)eventsBatches
                               reason:(AMAEventsCleanupReasonType)reasonType;

@end
