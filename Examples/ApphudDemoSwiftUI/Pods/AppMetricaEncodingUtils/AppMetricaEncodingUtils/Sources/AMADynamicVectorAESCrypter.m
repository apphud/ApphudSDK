
#import <AppMetricaEncodingUtils/AppMetricaEncodingUtils.h>
#import "AMAEncodingUtilsLog.h"
#import <CommonCrypto/CommonCryptor.h>

@implementation AMADynamicVectorAESCrypter

- (instancetype)initWithKey:(NSData *)key
{
    if (key == nil) {
        AMALogAssert(@"Key is nil");
        return nil;
    }
    self = [super init];
    if (self != nil) {
        _key = [key copy];
    }
    return self;
}

- (void)fillError:(NSError **)error withErorrCode:(NSInteger)errorCode
{
    NSError *internalError = [NSError errorWithDomain:kAMAAESDataEncoderErrorDomain
                                                 code:errorCode
                                             userInfo:nil];
    [AMAErrorUtilities fillError:error withError:internalError];
}

- (NSData *)encodeData:(NSData *)data error:(NSError **)error
{
    NSMutableData *result = nil;
    NSData *iv = [AMAAESUtility randomIv];
    AMAAESCrypter *aesCrypter = [[AMAAESCrypter alloc] initWithKey:[self key] iv:iv];
    NSData *encryptedData = [aesCrypter encodeData:data error:error];

    if (encryptedData != nil) {
        result = [NSMutableData dataWithCapacity:iv.length + encryptedData.length];
        [result appendData:iv];
        [result appendData:encryptedData];
    }
    return [result copy];
}

- (NSData *)decodeData:(NSData *)data error:(NSError **)error
{
    NSData *result = nil;
    NSRange ivRange = NSMakeRange(0, kAMAAESDataEncoderIVSize);
    if (data.length >= ivRange.length) {
        NSRange encodedDataRange = NSMakeRange(ivRange.length, data.length - ivRange.length);

        NSData *iv = [data subdataWithRange:ivRange];
        NSData *aesEncodedData = [data subdataWithRange:encodedDataRange];

        AMAAESCrypter *aesCrypter = [[AMAAESCrypter alloc] initWithKey:[self key] iv:iv];
        result = [aesCrypter decodeData:aesEncodedData error:error];
    }
    else {
        [self fillError:error withErorrCode:kCCParamError];
    }
    return result;
}

@end
