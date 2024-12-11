
#import "AMACore.h"
#import "AMAFileEventValue.h"
#import "AMAEncryptedFileStorageFactory.h"

@implementation AMAFileEventValue

- (instancetype)initWithRelativeFilePath:(NSString *)relativeFilePath
                          encryptionType:(AMAEventEncryptionType)encryptionType
{
    self = [super init];
    if (self != nil) {
        _encryptionType = encryptionType;
        _relativeFilePath = [relativeFilePath copy];
    }
    return self;
}

- (BOOL)empty
{
    return self.relativeFilePath.length == 0;
}

- (NSData *)dataWithError:(NSError **)error
{
    return [self dataWithEncryptionType:self.encryptionType error:error];
}

- (NSData *)gzippedDataWithError:(NSError *__autoreleasing *)error
{
    if (self.encryptionType != AMAEventEncryptionTypeGZip) {
        return nil;
    }
    return [self dataWithEncryptionType:AMAEventEncryptionTypeNoEncryption error:error];
}

- (NSData *)dataWithEncryptionType:(AMAEventEncryptionType)encryptionType error:(NSError **)error
{
    if (self.empty) {
        return nil;
    }

    NSError *internalError = nil;
    NSString *fullPath = [AMAFileUtility pathForFullFileName:self.relativeFilePath];
    id<AMAFileStorage> fileStorage = [AMAEncryptedFileStorageFactory fileStorageForEncryptionType:encryptionType
                                                                                         filePath:fullPath];
    NSData *content = [fileStorage readDataWithError:&internalError];
    if (internalError != nil) {
        AMALogError(@"Failed to read file content %@ with error: %@", self.relativeFilePath, internalError);
        [AMAErrorUtilities fillError:error withError:internalError];
        content = nil;
    }
    return content;
}

- (void)cleanup
{
    [AMAFileUtility deleteFileAtPath:[AMAFileUtility pathForFullFileName:self.relativeFilePath]];
}

@end
