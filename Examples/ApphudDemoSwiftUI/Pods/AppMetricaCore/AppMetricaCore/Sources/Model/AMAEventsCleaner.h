
#import <Foundation/Foundation.h>

@class AMAEventsCleanupInfo;
@protocol AMADatabaseProtocol;
@protocol AMAReporterProviding;

@interface AMAEventsCleaner: NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithReporterProvider:(id<AMAReporterProviding>)reporterProvider;

- (BOOL)purgeAndReportEventsForInfo:(AMAEventsCleanupInfo *)cleanupInfo
                           database:(id<AMADatabaseProtocol>)database
                              error:(NSError **)error;

@end
