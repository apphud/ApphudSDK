
#import "AMAEventNameHashProvider.h"
#import <CommonCrypto/CommonCrypto.h>

@implementation AMAEventNameHashProvider

- (NSNumber *)hashForEventName:(NSString *)eventName
{
    if (eventName == nil) {
        return @0;
    }
    NSData *data = [eventName dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
    uint64_t hash = 0;
    memcpy(&hash, digest + CC_SHA1_DIGEST_LENGTH - sizeof(uint64_t), sizeof(uint64_t));
    return [NSNumber numberWithUnsignedLongLong:hash];
}

@end
