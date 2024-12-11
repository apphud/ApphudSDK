
#import <AppMetricaEncodingUtils/AppMetricaEncodingUtils.h>
#import "AMAEncodingUtilsLog.h"
#include <zlib.h>

NSString *const kAMAGZipDataEncoderErrorDomain = @"kAMAGZipDataEncoderErrorDomain";

static int const kAMACompressionLevel = Z_DEFAULT_COMPRESSION;
static int const kAMAWindowBits = MAX_WBITS + 16;

@implementation AMAGZipDataEncoder

- (NSData *)encodeData:(NSData *)data error:(NSError **)error
{
    if (data.length == 0) {
        AMALogWarn(@"Can't compress an empty or null NSData object.");
        return nil;
    }

    z_stream zlibStream = [[self class] zlibStreamForData:data];
    int deflateStatus = deflateInit2(&zlibStream,
                                     kAMACompressionLevel,
                                     Z_DEFLATED,
                                     kAMAWindowBits,
                                     MAX_MEM_LEVEL,
                                     Z_DEFAULT_STRATEGY);

    NSString *errorMsg = [[self class] zlibInitErrorDescription:deflateStatus];
    if (errorMsg != nil) {
        [[self class] fillError:error withCode:deflateStatus description:errorMsg];
        AMALogError(@"deflateInit2() Error: \"%@\" Message: \"%s\"", errorMsg, zlibStream.msg);
        deflateEnd(&zlibStream);
        return nil;
    }

    uLong expectedLength = deflateBound(&zlibStream, data.length);
    NSMutableData *compressedData = [NSMutableData dataWithLength:expectedLength];
    unsigned char *buffer = compressedData.mutableBytes;
    NSUInteger compressedLength = compressedData.length;

    do {
        zlibStream.next_out = buffer + zlibStream.total_out;
        zlibStream.avail_out = (uInt)(compressedLength - zlibStream.total_out);
        deflateStatus = deflate(&zlibStream, Z_FINISH);
    } while ( deflateStatus == Z_OK );

    compressedData.length = zlibStream.total_out;
    deflateEnd(&zlibStream);

    if (deflateStatus != Z_STREAM_END) {
        errorMsg = [[self class] zlibErrorDescription:deflateStatus];
        if (errorMsg != nil) {
            [[self class] fillError:error withCode:deflateStatus description:errorMsg];
            AMALogError(@"zlib error while attempting compression: \"%@\" Message: \"%s\"", errorMsg, zlibStream.msg);
            return nil;
        }
    }

    AMALogInfo(@"Data compressed(%lu -> %lu)",
               (unsigned long)data.length, (unsigned long)compressedData.length);
    return [compressedData copy];
}

- (NSData *)decodeData:(NSData *)data error:(NSError **)error
{
    if (data.length == 0) {
        AMALogWarn(@"Can't decompress an empty or null NSData object.");
        return nil;
    }

    z_stream zlibStream = [[self class] zlibStreamForData:data];
    int inflateStatus = inflateInit2(&zlibStream, kAMAWindowBits);

    NSString *errorMsg = [[self class] zlibInitErrorDescription:inflateStatus];
    if (errorMsg != nil) {
        [[self class] fillError:error withCode:inflateStatus description:errorMsg];
        AMALogError(@"inflateInit2() Error: \"%@\" Message: \"%s\"", errorMsg, zlibStream.msg);
        inflateEnd(&zlibStream);
        return nil;
    }

    NSUInteger halfLength = data.length / 2;
    NSMutableData *decompressedData = [NSMutableData dataWithLength:data.length + halfLength];

    do {
        if (zlibStream.total_out >= decompressedData.length) {
            [decompressedData increaseLengthBy:halfLength];
        }

        zlibStream.next_out = (Bytef *)(decompressedData.mutableBytes + zlibStream.total_out);
        zlibStream.avail_out = (uInt)(decompressedData.length - zlibStream.total_out);
        inflateStatus = inflate(&zlibStream, Z_SYNC_FLUSH);
    } while ( inflateStatus == Z_OK );

    decompressedData.length = zlibStream.total_out;
    inflateEnd(&zlibStream);

    if (inflateStatus != Z_STREAM_END) {
        errorMsg = [[self class] zlibErrorDescription:inflateStatus];
        if (errorMsg != nil) {
            [[self class] fillError:error withCode:inflateStatus description:errorMsg];
            AMALogError(@"zlib error while attempting decompression: \"%@\" Message: \"%s\"", errorMsg, zlibStream.msg);
            return nil;
        }
    }

    AMALogInfo(@"Data decompressed(%lu -> %lu)",
               (unsigned long)data.length, (unsigned long)decompressedData.length);
    return [decompressedData copy];
}

+ (z_stream)zlibStreamForData:(NSData *)data
{
    z_stream zlibStreamStruct;
    zlibStreamStruct.zalloc    = Z_NULL;
    zlibStreamStruct.zfree     = Z_NULL;
    zlibStreamStruct.opaque    = Z_NULL;
    zlibStreamStruct.total_out = 0;
    zlibStreamStruct.next_in   = (Bytef *)data.bytes;
    zlibStreamStruct.avail_in  = (uInt)data.length;
    return zlibStreamStruct;
}

+ (NSString *)zlibInitErrorDescription:(int)errorCode
{
    switch (errorCode) {
        case Z_OK:
            return nil;
        case Z_STREAM_ERROR:
            return @"Invalid parameter passed in to function.";
        case Z_MEM_ERROR:
            return @"Insufficient memory.";
        case Z_VERSION_ERROR:
            return @"The version of zlib.h and the version of the library linked do not match.";
        default:
            return @"Unknown error code.";
    }
}

+ (NSString *)zlibErrorDescription:(int)errorCode
{
    switch (errorCode) {
        case Z_OK:
            return nil;
        case Z_STREAM_END:
            return @"End of stream";
        case Z_ERRNO:
            return @"Error occured while reading file.";
        case Z_STREAM_ERROR:
            return @"The stream state was inconsistent (e.g., next_in or next_out was NULL).";
        case Z_DATA_ERROR:
            return @"The deflate data was invalid or incomplete.";
        case Z_MEM_ERROR:
            return @"Memory could not be allocated for processing.";
        case Z_BUF_ERROR:
            return @"Ran out of output buffer for writing compressed bytes.";
        case Z_VERSION_ERROR:
            return @"The version of zlib.h and the version of the library linked do not match.";
        default:
            return @"Unknown error code.";
    }
}

+ (void)fillError:(NSError **)error withCode:(int)errorCode description:(NSString *)description
{
    [AMAErrorUtilities fillError:error
                       withError:[NSError errorWithDomain:kAMAGZipDataEncoderErrorDomain
                                                     code:errorCode
                                                 userInfo:@{ NSLocalizedDescriptionKey: description ?: @"" }]];
}

#ifdef DEBUG

+ (NSString *)stringForSize:(NSUInteger)size
{
    if (size > 1024) {
        return [NSString stringWithFormat:@"%lu KB", (unsigned long)size / 1024];
    }
    else {
        return [NSString stringWithFormat:@"%lu B", (unsigned long)size];
    }
}

+ (void)logCompressionForData:(NSData *)data compressedData:(NSData *)compressedData
{
    AMALogInfo(@"GZIP: Compressed data from %@ to %@",
                       [self stringForSize:data.length], [self stringForSize:compressedData.length]);
}

#endif

@end
