
#import <Foundation/Foundation.h>

@class AMALogMessage;

@protocol AMALogMessageFormatting <NSObject>

- (NSString *)messageToString:(AMALogMessage *)message;

@end
