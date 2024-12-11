
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

@implementation AMAPermissiveTruncator

- (NSString *)truncatedString:(NSString *)string onTruncation:(AMATruncationBlock)onTruncation
{
    return string;
}

- (NSData *)truncatedData:(NSData *)data onTruncation:(AMATruncationBlock)onTruncation
{
    return data;
}

@end
