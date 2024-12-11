
#import <AppMetricaEncodingUtils/AppMetricaEncodingUtils.h>
#import <CommonCrypto/CommonCrypto.h>
#import "AMAEncodingUtilsLog.h"

NSString *const kAMAAESDataEncoderErrorDomain = @"io.appmetrica.AMAAESCrypter";
NSUInteger const kAMAAESDataEncoderIVSize = kCCBlockSizeAES128;
NSUInteger const kAMAAESDataEncoder128BitKeySize = kCCKeySizeAES128;

@implementation AMAAESCrypter

- (instancetype)initWithKey:(NSData *)key iv:(NSData *)iv
{
    self = [super init];
    if (self != nil) {
        _key = [key copy];
        _iv = [iv copy];
    }
    return self;
}

- (NSData *)processData:(NSData *)data operationType:(CCOperation)operationType
                  error:(NSError **)error
{
    size_t bufferSize = data.length + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);

    size_t sizeProcessed = 0;
    CCCryptorStatus cryptStatus = CCCrypt(operationType,
                                          kCCAlgorithmAES,
                                          kCCOptionPKCS7Padding,
                                          [self.key bytes],
                                          [self.key length],
                                          [self.iv bytes],
                                          [data bytes],
                                          [data length],
                                          buffer,
                                          bufferSize,
                                          &sizeProcessed);

    NSData *result = nil;
    if (cryptStatus == kCCSuccess) {
        result = [NSData dataWithBytesNoCopy:buffer length:sizeProcessed];
    }
    else {
        if (error != NULL) {
            *error = [NSError errorWithDomain:kAMAAESDataEncoderErrorDomain
                                         code:cryptStatus
                                     userInfo:nil];
        }

        free(buffer);
    }

    AMALogInfo(@"AES encryption process(%ud) finished(%lu -> %lu)",
        operationType, (unsigned long)data.length, (unsigned long)result.length);
    return result;
}

- (NSData *)encodeData:(NSData *)data error:(NSError **)error
{
    return [self processData:data operationType:kCCEncrypt error:error];
}

- (NSData *)decodeData:(NSData *)data error:(NSError **)error
{
    return [self processData:data operationType:kCCDecrypt error:error];
}

@end
