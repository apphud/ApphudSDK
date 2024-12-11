
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

@interface AMALengthStringTruncator ()

@property (nonatomic, assign, readonly) NSUInteger maxLength;

@end

@implementation AMALengthStringTruncator

- (instancetype)initWithMaxLength:(NSUInteger)maxLength
{
    self = [super init];
    if (self != nil) {
        _maxLength = maxLength;
    }
    return self;
}

- (NSString *)truncatedString:(NSString *)string onTruncation:(AMATruncationBlock)onTruncation
{
    if (string.length <= self.maxLength) {
        return string;
    }

    NSRange range = [string rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, self.maxLength)];
    NSString *truncatedString = [string substringWithRange:range];
    if (onTruncation != nil) {
        NSRange remainingRange = NSMakeRange(self.maxLength, string.length - self.maxLength);
        NSUInteger usedLength = 0;
        [string getBytes:NULL
               maxLength:NSUIntegerMax
              usedLength:&usedLength
                encoding:NSUTF8StringEncoding
                 options:0
                   range:remainingRange
          remainingRange:NULL];
        onTruncation(usedLength);
    }
    return truncatedString;
}

@end
