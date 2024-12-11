
#import <AppMetricaEncodingUtils/AppMetricaEncodingUtils.h>

// PKCS #1 rsaEncryption szOID_RSA_RSA
static unsigned char const kAMASequoid[] =
    { 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00};

@implementation AMARSAUtility

#pragma mark - Public

+ (NSData *)publicKeyFromPem:(NSString *)pemString
{
    NSString *prefix = @"";
    NSString *keyType = @"PUBLIC";

    NSArray *ranges = [self pemHeaders:pemString forKeyOfType:keyType withPrefix:prefix];
    if (ranges == nil) {
        prefix = @"RSA ";
        ranges = [self pemHeaders:pemString forKeyOfType:keyType withPrefix:prefix];
    }

    NSData *encodedKeyData = nil;

    if (ranges != nil) {
        encodedKeyData = [self stripPemHeaders:ranges andDecodeContentOfPem:pemString];

        if ([prefix isEqualToString:@""]) {
            encodedKeyData = [self stripX509PublicKeyHeader:encodedKeyData];
        }
    }

    return encodedKeyData;
}

+ (NSData *)privateKeyFromPem:(NSString *)pemString
{
    NSString *prefix = @"";
    NSString *keyType = @"PRIVATE";

    NSArray *ranges = [self pemHeaders:pemString forKeyOfType:keyType withPrefix:prefix];
    if (ranges == nil) {
        prefix = @"RSA ";
        ranges = [self pemHeaders:pemString forKeyOfType:keyType withPrefix:prefix];
    }

    NSData *encodedKeyData = nil;

    if (ranges != nil) {
        encodedKeyData = [self stripPemHeaders:ranges andDecodeContentOfPem:pemString];

        if ([prefix isEqualToString:@""]) {
            encodedKeyData = [self stripX509PrivateKeyHeader:encodedKeyData];
        }
    }

    return encodedKeyData;
}

#pragma mark - Private

+ (NSArray *)pemHeaders:(NSString *)pemString forKeyOfType:(NSString *)keyType
             withPrefix:(NSString *)prefix
{
    NSString *header = [NSString stringWithFormat: @"-----BEGIN %@%@ KEY-----", prefix, keyType];
    NSRange spos = [pemString rangeOfString:header];

    header = [NSString stringWithFormat: @"-----END %@%@ KEY-----", prefix, keyType];
    NSRange epos = [pemString rangeOfString:header];

    NSArray *result = nil;

    if (spos.location != NSNotFound && epos.location != NSNotFound) {
        result = @[[NSValue valueWithRange:spos], [NSValue valueWithRange:epos]];
    }

    return result;
}

+ (NSData *)stripPemHeaders:(NSArray *)headers andDecodeContentOfPem:(NSString *)pemString
{
    NSRange spos = [headers[0] rangeValue];
    NSRange epos = [headers[1] rangeValue];

    NSUInteger s = spos.location + spos.length;
    NSUInteger e = epos.location;
    NSRange range = NSMakeRange(s, e-s);
    pemString = [pemString substringWithRange:range];

    pemString = [pemString stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    pemString = [pemString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    pemString = [pemString stringByReplacingOccurrencesOfString:@"\t" withString:@""];
    pemString = [pemString stringByReplacingOccurrencesOfString:@" "  withString:@""];

    return [[NSData alloc] initWithBase64EncodedString:pemString options:0];
}

+ (NSData *)stripX509PublicKeyHeader:(NSData *)d_key
{
    NSData *result = nil;
    unsigned long len = 0;
    BOOL proceed = d_key != nil;

    if (proceed) {
        len = [d_key length];
        proceed = len != 0;
    }

    unsigned char *c_key = NULL;
    unsigned int  idx = 0;

    if (proceed) {
        c_key = (unsigned char *)[d_key bytes];
        proceed = c_key[idx++] == 0x30;
    }

    if (proceed) {
        if (c_key[idx] > 0x80) {
            idx += c_key[idx] - 0x80 + 1;
        }
        else {
            idx++;
        }

        proceed = memcmp(&c_key[idx], kAMASequoid, 15) == 0;
    }

    if (proceed) {
        idx += 15;
        proceed = c_key[idx++] == 0x03;
    }

    if (proceed) {
        if (c_key[idx] > 0x80) {
            idx += c_key[idx] - 0x80 + 1;
        }
        else {
            idx++;
        }

        proceed = c_key[idx++] == '\0';
    }

    if (proceed) {
        result = [NSData dataWithBytes:&c_key[idx] length:len - idx];
    }

    return result;
}

+ (NSData *)stripX509PrivateKeyHeader:(NSData *)d_key
{
    NSData *result = nil;
    BOOL proceed = d_key != nil;

    unsigned long len = 0;

    if (proceed) {
        len = [d_key length];
        proceed = len != 0;
    }

    unsigned char *c_key = NULL;
    unsigned int  idx = 7;

    if (proceed) {
        c_key = (unsigned char *)[d_key bytes];
        proceed = memcmp(&c_key[idx], kAMASequoid, 15) == 0;
    }

    if (proceed) {
        idx = 22;
        proceed = 0x04 == c_key[idx++];
    }

    if (proceed) {
        if (c_key[idx] > 0x80) {
            idx += c_key[idx] - 0x80 + 1;
        }
        else {
            idx++;
        }

        result = [d_key subdataWithRange:NSMakeRange(idx, len - idx)];
    }

    return result;
}

@end
