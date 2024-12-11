
#import "AMAEvent.h"
#import "AMAEventValueProtocol.h"

@implementation AMAEvent

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _createdAt = [NSDate date];
        _type = AMAEventTypeClient;
        _name = @"";
        _value = nil;
        _locationEnabled = AMAOptionalBoolUndefined;
        _firstOccurrence = AMAOptionalBoolUndefined;
        _bytesTruncated = 0;
    }

    return self;
}

#if AMA_ALLOW_DESCRIPTIONS
- (NSString *)description
{
    NSString *descr = [super description];
    return [NSString stringWithFormat:@"%@, type: %lu, sessionOid: %@, sequenceNumber: %lu, name: %@",
            descr, (unsigned long)self.type, self.sessionOid, (unsigned long)self.sequenceNumber, self.name];
}
#endif

- (void)cleanup
{
    if ([self.value respondsToSelector:@selector(cleanup)]) {
        [self.value cleanup];
    }
}

@end
