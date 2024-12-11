
#import "AMADate.h"

@implementation AMADate

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if ([object isKindOfClass:[self class]] == NO) return NO;
    return [self isEqualToDate:(AMADate *)object];
}

- (BOOL)isEqualToDate:(AMADate *)date
{
    if (date == nil) return NO;

    return ((self.deviceDate == nil && date.deviceDate == nil)
           || [self.deviceDate isEqualToDate:date.deviceDate])
        &&((self.serverTimeOffset == nil && date.serverTimeOffset == nil)
           || [self.serverTimeOffset isEqualToNumber:date.serverTimeOffset]);
}

- (NSUInteger)hash
{
    NSUInteger prime = 31;
    NSUInteger result = 1;

    result = prime * result + [self.deviceDate hash];
    result = prime * result + [self.serverTimeOffset hash];

    return result;
}

#if AMA_ALLOW_DESCRIPTIONS
- (NSString *)description
{
    NSString *description = nil;
    NSString *date = [self.deviceDate description];
    if (date.length > 0) {
        description = self.deviceDate.description;
        if (self.serverTimeOffset != nil) {
            description = [description stringByAppendingFormat:@" Offset: %@", self.serverTimeOffset];
        }
    }
    else {
        description = super.description;
    }
    return [description copy];
}
#endif

@end
