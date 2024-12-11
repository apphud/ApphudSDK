
#import "AMALogMessageFormatting.h"

typedef NSString * (^AMABlockLogMessageFormatterCallback)(AMALogMessage *message);

@interface AMABlockLogMessageFormatter : NSObject <AMALogMessageFormatting>

+ (instancetype)formatterWithBlock:(AMABlockLogMessageFormatterCallback)formatCallback;

- (instancetype)initWithFormatterBlock:(AMABlockLogMessageFormatterCallback)formatCallback;

@end
