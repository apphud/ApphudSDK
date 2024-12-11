
#import <AppMetricaEncodingUtils/AppMetricaEncodingUtils.h>
#import "AMAEncryptedFileStorageFactory.h"
#import "AMAEncryptedFileStorage.h"

@implementation AMAEncryptedFileStorageFactory

#pragma mark - Public -

+ (id<AMAFileStorage>)fileStorageForEncryptionType:(AMAEventEncryptionType)encryptionType filePath:(NSString *)filePath
{
    AMADiskFileStorage *diskFileStorage = [[AMADiskFileStorage alloc] initWithPath:filePath
                                                                           options:AMADiskFileStorageOptionNoBackup];
    switch (encryptionType) {
        case AMAEventEncryptionTypeNoEncryption:
            return diskFileStorage;

        case AMAEventEncryptionTypeAESv1:
            return [self aesV1FileStorageWithDiskFileStorage:diskFileStorage];

        case AMAEventEncryptionTypeGZip:
            return [self gzipFileStorageWithDiskFileStorage:diskFileStorage];
            
        default:
            return diskFileStorage;
    }
}

#pragma mark - Private -

+ (id<AMAFileStorage>)aesV1FileStorageWithDiskFileStorage:(id<AMAFileStorage>)diskFileStorage
{
    id<AMADataEncoding> encoder = [[AMAAESCrypter alloc] initWithKey:[self message] iv:[AMAAESUtility defaultIv]];
    return [[AMAEncryptedFileStorage alloc] initWithUnderlyingStorage:diskFileStorage encoder:encoder];
}

+ (id<AMAFileStorage>)gzipFileStorageWithDiskFileStorage:(id<AMAFileStorage>)diskFileStorage
{
    id<AMADataEncoding> encoder = [[AMAGZipDataEncoder alloc] init];
    return [[AMAEncryptedFileStorage alloc] initWithUnderlyingStorage:diskFileStorage encoder:encoder];
}

+ (NSData *)message
{
    const unsigned char data[] = {
        0xeb, 0x45, 0x3e, 0xb2, 0x31, 0xb2, 0x40, 0xb6, 0xb1, 0xb0, 0xa7, 0xd1, 0xb6, 0x78, 0xa5, 0x46,
    };
    return [NSData dataWithBytes:data length:16];
}

@end
