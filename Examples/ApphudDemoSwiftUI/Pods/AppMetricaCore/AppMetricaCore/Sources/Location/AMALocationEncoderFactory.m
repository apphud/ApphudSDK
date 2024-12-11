
#import <AppMetricaEncodingUtils/AppMetricaEncodingUtils.h>
#import "AMALocationEncoderFactory.h"
#import "AMAAESUtility+Migration.h"
#import "AMAMigrationTo500Utils.h"

@implementation AMALocationEncoderFactory

+ (id<AMADataEncoding>)encoder
{
    return [[AMAAESCrypter alloc] initWithKey:[self message] iv:[AMAAESUtility defaultIv]];
}

+ (id<AMADataEncoding>)migrationEncoder
{
    return [[AMAAESCrypter alloc] initWithKey:[self message] iv:[AMAAESUtility migrationIv:kAMAMigrationBundle]];
}

+ (NSData *)message
{
    // This is an encryption key for AES algorithm
    const unsigned char data[] = {
        0x04, 0xf3, 0x88, 0x78, 0x96, 0xe0, 0x48, 0x7f, 0x86, 0x7c, 0x0d, 0xe4, 0x45, 0xea, 0x0a, 0x11,
    };
    return [NSData dataWithBytes:data length:16];
}

@end
