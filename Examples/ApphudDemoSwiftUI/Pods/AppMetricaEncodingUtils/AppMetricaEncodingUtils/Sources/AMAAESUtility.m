
#import <AppMetricaEncodingUtils/AppMetricaEncodingUtils.h>
#import <CommonCrypto/CommonCrypto.h>
#import <AppMetricaPlatform/AppMetricaPlatform.h>
#import "AMAEncodingUtilsLog.h"

@implementation AMAAESUtility

#pragma mark - Public
+ (NSData *)randomKeyOfSize:(NSUInteger)size
{
    return [self randomDataOfSize:size];
}

+ (NSData *)randomIv
{
    return [self randomDataOfSize:kAMAAESDataEncoderIVSize];
}

+ (NSData *)defaultIv
{
    NSString *sourceString = [AMAPlatformDescription appID] ?: [AMAPlatformDescription SDKBundleName];
    return [self ivWithSource:sourceString];
}

#pragma mark - Private -
+ (NSData *)randomDataOfSize:(NSUInteger)size
{
    void *bytes = malloc(size);
    if (SecRandomCopyBytes(kSecRandomDefault, size, bytes) != errSecSuccess) {
        AMALogAssert(@"Can't retrieve secure random bytes. Using the fallback to arc4random_buf.");
        arc4random_buf(bytes, size);
    }
    return [NSData dataWithBytesNoCopy:bytes length:size];
}

+ (NSData *)ivWithSource:(NSString *)sourceString
{
    const char *pointer = [sourceString UTF8String];
    unsigned char *md5Buffer = malloc(CC_MD5_DIGEST_LENGTH);
    CC_MD5(pointer, (CC_LONG)strlen(pointer), md5Buffer);
    NSData *md5Data = [NSData dataWithBytesNoCopy:md5Buffer length:CC_MD5_DIGEST_LENGTH];
    return md5Data;
}

#pragma mark - Migration -
+ (NSData *)migrationIv:(NSString *)migrationSource
{
    NSString *sourceString = [AMAPlatformDescription appID] ?: migrationSource;
    return [self ivWithSource:sourceString];
}

@end
