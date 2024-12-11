
#import <AppMetricaEncodingUtils/AppMetricaEncodingUtils.h>
#import "AMAReportPayloadEncoderFactory.h"

@implementation AMAReportPayloadEncoderFactory

+ (id<AMADataEncoding>)encoder
{
    AMARSAAESCrypter *rsaAESCrypter = [[AMARSAAESCrypter alloc] initWithPublicKey:[self message] privateKey:nil];
    AMAGZipDataEncoder *gzipEncoder = [[AMAGZipDataEncoder alloc] init];
    NSArray *encoders = @[
        gzipEncoder,
        rsaAESCrypter,
    ];
    return [[AMACompositeDataEncoder alloc] initWithEncoders:encoders];
}

+ (AMARSAKey *)message
{
    static AMARSAKey *key = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSData *keyData = [AMARSAUtility publicKeyFromPem:[AMARSACrypter message]];
        key = [[AMARSAKey alloc] initWithData:keyData
                                      keyType:AMARSAKeyTypePublic
                                    uniqueTag:kAMARSAKeyTagReporter];
    });
    return key;
}

@end
