
#import <Foundation/Foundation.h>
#import "AMAExceptionFormatting.h"

@protocol AMADateProviding;
@class AMADecodedCrashSerializer;
@class AMABacktraceSymbolicator;
@class AMACrashReportDecoder;

@interface AMAExceptionFormatter : NSObject <AMAExceptionFormatting>

- (instancetype)initWithDateProvider:(id<AMADateProviding>)dateProvider
                          serializer:(AMADecodedCrashSerializer *)serializer
                        symbolicator:(AMABacktraceSymbolicator *)symbolicator
                             decoder:(AMACrashReportDecoder *)decoder;
@end
