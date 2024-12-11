
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

@interface AMAFullDataTruncator ()

@property (nonatomic, assign, readonly) NSUInteger maxLength;

@end

@implementation AMAFullDataTruncator

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
    if (data.length > self.maxLength) {
        if (onTruncation != nil) {
            onTruncation(data.length);
        }
        return nil;
    }
    return data.copy;
}

@end
