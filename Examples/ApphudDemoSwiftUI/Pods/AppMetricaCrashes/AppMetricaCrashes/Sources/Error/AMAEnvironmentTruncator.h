
#import <Foundation/Foundation.h>
#import "AMACrashLogging.h"

@protocol AMAStringTruncating;

@interface AMAEnvironmentTruncator : NSObject <AMADictionaryTruncating>

- (instancetype)initWithParameterKeyTruncator:(id<AMAStringTruncating>)parameterKeyTruncator
                      parameterValueTruncator:(id<AMAStringTruncating>)parameterValueTruncator
                           maxParametersCount:(NSUInteger)maxParametersCount;

@end
