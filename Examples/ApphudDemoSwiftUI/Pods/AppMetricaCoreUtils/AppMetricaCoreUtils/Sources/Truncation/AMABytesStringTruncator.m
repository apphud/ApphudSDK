
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

@interface AMABytesStringTruncator ()

@property (nonatomic, assign, readonly) NSUInteger maxBytesLength;

@end

@implementation AMABytesStringTruncator

- (instancetype)initWithMaxBytesLength:(NSUInteger)maxBytesLength
{
    self = [super init];
    if (self != nil) {
        _maxBytesLength = maxBytesLength;
    }
    return self;
}

- (NSString *)truncatedString:(NSString *)string onTruncation:(AMATruncationBlock)onTruncation
{
    BOOL isTruncationPossiblyRequired = string.length > 0 &&
        [string maximumLengthOfBytesUsingEncoding:NSUTF8StringEncoding] > self.maxBytesLength;
    if (isTruncationPossiblyRequired == NO) {
        return string;
    }

    NSUInteger bytesLength = [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    if (bytesLength <= self.maxBytesLength) {
        return string;
    }

    NSMutableData *stringData = [NSMutableData dataWithLength:self.maxBytesLength];
    NSUInteger usedLength = 0;
    [string getBytes:stringData.mutableBytes
           maxLength:self.maxBytesLength
          usedLength:&usedLength
            encoding:NSUTF8StringEncoding
             options:0
               range:NSMakeRange(0, string.length)
      remainingRange:NULL];
    stringData.length = usedLength;
    NSString *truncatedString = [[NSString alloc] initWithData:stringData encoding:NSUTF8StringEncoding];

    if (onTruncation != nil) {
        onTruncation(bytesLength - usedLength);
    }

    return truncatedString;
}

@end
