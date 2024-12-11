
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

@interface AMADataTruncator ()

@property (nonatomic, assign, readonly) NSUInteger maxLength;

@end

@implementation AMADataTruncator

- (instancetype)initWithMaxLength:(NSUInteger)maxLength
{
    self = [super init];
    if (self != nil) {
        _maxLength = maxLength;
    }
    return self;
}

- (NSData *)truncatedData:(NSData *)data onTruncation:(AMATruncationBlock)onTruncation
{
    if (data.length <= self.maxLength) {
        return data;
    }

    NSData *truncatedData = [data subdataWithRange:NSMakeRange(0, self.maxLength)];
    if (onTruncation != nil) {
        onTruncation(data.length - self.maxLength);
    }
    return truncatedData;
}

@end
