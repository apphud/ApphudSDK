
#import "AMALogMessageFormatting.h"

@interface AMAComposedLogMessageFormatter : NSObject <AMALogMessageFormatting>

- (instancetype)initWithFormatters:(NSArray *)formatters;

@end
