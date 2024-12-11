
#import <Foundation/Foundation.h>

@protocol AMALogMessageFormatting;

typedef NS_ENUM(NSInteger, AMALogFormatPart) {
    AMALogFormatPartDate,
    AMALogFormatPartOrigin,
    AMALogFormatPartContent,
    AMALogFormatPartBacktrace,
    AMALogFormatPartPublicPrefix,
};

@interface AMALogMessageFormatterFactory : NSObject

- (instancetype)initWithFormatters:(NSDictionary *)formatters;

- (id<AMALogMessageFormatting>)formatterWithFormatParts:(NSArray *)format;

@end
