
#import <Foundation/Foundation.h>

@protocol AMAStringTruncating;
@protocol AMADictionaryTruncating;
@class AMAPluginErrorDetails;
@class AMAVirtualMachineCrash;
@class AMAStackTraceElement;
@class AMABacktrace;
@class AMAVirtualMachineInfo;

@interface AMACrashObjectsFactory : NSObject

+ (instancetype)sharedInstance;

- (instancetype)initWithMessageTruncator:(id<AMAStringTruncating>)messageTruncator
                    environmentTruncator:(id<AMADictionaryTruncating>)environmentTruncator
                    shortStringTruncator:(id<AMAStringTruncating>)shortStringTruncator
                 maxBacktraceFramesCount:(NSUInteger)maxBacktraceFramesCount;

- (AMAVirtualMachineInfo *)virtualMachineInfoForErrorDetails:(AMAPluginErrorDetails *)errorDetails
                                              bytesTruncated:(NSUInteger *)bytesTruncated;
- (AMABacktrace *)backtraceFrom:(NSArray<AMAStackTraceElement *> *)originalBacktrace
                 bytesTruncated:(NSUInteger *)bytesTruncated;
- (AMAVirtualMachineCrash *)virtualMachineCrashForErrorDetails:(AMAPluginErrorDetails *)errorDetails
                                                bytesTruncated:(NSUInteger *)bytesTruncated;

@end
