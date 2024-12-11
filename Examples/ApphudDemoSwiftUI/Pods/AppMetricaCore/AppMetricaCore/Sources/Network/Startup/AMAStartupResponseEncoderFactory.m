
#import <AppMetricaEncodingUtils/AppMetricaEncodingUtils.h>
#import "AMAStartupResponseEncoderFactory.h"

@implementation AMAStartupResponseEncoderFactory

+ (id<AMADataEncoding>)encoder
{
    AMADynamicVectorAESCrypter *aesCrypter = [[AMADynamicVectorAESCrypter alloc] initWithKey:[self message]];
    AMAGZipDataEncoder *gzipEncoder = [[AMAGZipDataEncoder alloc] init];
    NSArray *encoders = @[
        gzipEncoder,
        aesCrypter,
    ];
    return [[AMACompositeDataEncoder alloc] initWithEncoders:encoders];
}

+ (NSData *)message
{
    // This is an encryption key for AES algorithm
    const unsigned char data[] = {
        0x68, 0x42, 0x6e, 0x42, 0x51, 0x62, 0x5a, 0x72, 0x6d, 0x6a, 0x50, 0x58, 0x45, 0x57, 0x56, 0x4a, 0x0a,
    };
    return [NSData dataWithBytes:data length:16];
}

@end
