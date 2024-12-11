
#import <AppMetricaEncodingUtils/AppMetricaEncodingUtils.h>

NSString *const kAMARSAAESCrypterErrorDomain = @"kAMARSAAESCrypterErrorDomain";

static NSUInteger const kAMAEncryptedKeysPrefixSize = 128;

@interface AMARSAAESCrypter ()

@property (nonatomic, strong, readonly) id<AMADataEncoding> keyEncoder;

@end

@implementation AMARSAAESCrypter

- (instancetype)initWithPublicKey:(AMARSAKey *)publicKey privateKey:(AMARSAKey *)privateKey
{
    self = [super init];
    if (self != nil) {
        _keyEncoder = [[AMARSACrypter alloc] initWithPublicKey:publicKey privateKey:privateKey];
    }
    return self;
}

- (NSError *)incorrectFormatError
{
    return [NSError errorWithDomain:kAMARSAAESCrypterErrorDomain
                               code:-1
                           userInfo:nil];
}

- (NSData *)encodeData:(NSData *)data error:(NSError **)error
{
    NSMutableData *result = nil;
    NSError *currentError = nil;

    NSData *key = [AMAAESUtility randomKeyOfSize:kAMAAESDataEncoder128BitKeySize];
    NSData *iv = [AMAAESUtility randomIv];
    AMAAESCrypter *contentCrypter = [[AMAAESCrypter alloc] initWithKey:key iv:iv];

    data = [contentCrypter encodeData:data error:&currentError];
    if (currentError == nil) {
        NSMutableData *prefixData =
            [NSMutableData dataWithCapacity:key.length + iv.length];
        [prefixData appendData:key];
        [prefixData appendData:iv];

        NSData *encryptedPrefixData = [self.keyEncoder encodeData:[prefixData copy] error:&currentError];
        if (currentError == nil) {
            result = [NSMutableData dataWithCapacity:encryptedPrefixData.length + data.length];
            [result appendData:encryptedPrefixData];
            [result appendData:data];
        }
    }

    if (currentError != nil) {
        [AMAErrorUtilities fillError:error withError:currentError];
    }
    return [result copy];
}

- (NSData *)decodeData:(NSData *)data error:(NSError **)error
{
    NSData *result = nil;
    NSError *currentError = nil;

    if (data.length >= kAMAEncryptedKeysPrefixSize) {
        NSRange prefixRange = NSMakeRange(0, kAMAEncryptedKeysPrefixSize);
        NSData *encryptedPrefix = [data subdataWithRange:prefixRange];
        NSData *prefix = [self.keyEncoder decodeData:encryptedPrefix error:&currentError];
        if (currentError == nil) {
            if (prefix.length >= kAMAAESDataEncoder128BitKeySize + kAMAAESDataEncoderIVSize) {
                NSRange keyRange = NSMakeRange(0, kAMAAESDataEncoder128BitKeySize);
                NSData *key = [prefix subdataWithRange:keyRange];

                NSRange ivRange = NSMakeRange(NSMaxRange(keyRange), kAMAAESDataEncoderIVSize);
                NSData *iv = [prefix subdataWithRange:ivRange];
                AMAAESCrypter *contentCrypter = [[AMAAESCrypter alloc] initWithKey:key iv:iv];

                NSRange contentRange = NSMakeRange(NSMaxRange(prefixRange), data.length - prefixRange.length);
                NSData *encryptedContent = [data subdataWithRange:contentRange];

                result = [contentCrypter decodeData:encryptedContent error:&currentError];
            }
            else {
                currentError = [self incorrectFormatError];
            }
        }
    }
    else {
        currentError = [self incorrectFormatError];
    }

    if (currentError != nil) {
        [AMAErrorUtilities fillError:error withError:currentError];
    }
    return [result copy];
}

@end
