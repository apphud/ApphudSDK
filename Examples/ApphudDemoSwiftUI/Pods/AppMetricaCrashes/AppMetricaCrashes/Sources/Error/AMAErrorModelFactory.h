
#import <Foundation/Foundation.h>
#import "AMAErrorRepresentable.h"

@class AMAErrorModel;
@protocol AMAStringTruncating;
@class AMAPluginErrorDetails;

@protocol AMADictionaryTruncating;

@interface AMAErrorModelFactory : NSObject

+ (instancetype)sharedInstance;

- (instancetype)initWithDomainTruncator:(id<AMAStringTruncating>)domainTruncator
                    identifierTruncator:(id<AMAStringTruncating>)identifierTruncator
                       messageTruncator:(id<AMAStringTruncating>)messageTruncator
                   environmentTruncator:(id<AMADictionaryTruncating>)environmentTruncator
                   shortStringTruncator:(id<AMAStringTruncating>)shortStringTruncator
               maxUnderlyingErrorsCount:(NSUInteger)maxUnderlyingErrorsCount
                maxBacktraceFramesCount:(NSUInteger)maxBacktraceFramesCount;

- (AMAErrorModel *)modelForNSError:(NSError *)error options:(AMAErrorReportingOptions)options;
- (AMAErrorModel *)modelForErrorRepresentable:(id<AMAErrorRepresentable>)error
                                      options:(AMAErrorReportingOptions)options;
- (AMAErrorModel *)defaultModelForErrorDetails:(AMAPluginErrorDetails *)details
                                bytesTruncated:(NSUInteger *)bytesTruncated;
- (AMAErrorModel *)customModelForErrorDetails:(AMAPluginErrorDetails *)details
                                   identifier:(NSString *)identifier
                               bytesTruncated:(NSUInteger *)bytesTruncated;

@end
