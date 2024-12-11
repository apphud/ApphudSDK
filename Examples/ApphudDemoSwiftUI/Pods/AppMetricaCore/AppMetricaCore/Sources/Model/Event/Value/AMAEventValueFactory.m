
#import "AMACore.h"
#import "AMAEventValueFactory.h"
#import "AMAStringEventValue.h"
#import "AMABinaryEventValue.h"
#import "AMAFileEventValue.h"
#import "AMAEncryptedFileStorageFactory.h"

@interface AMAEventValueFactory ()

@property (nonatomic, strong, readonly) id<AMAStringTruncating> stringTruncator;
@property (nonatomic, strong, readonly) id<AMADataTruncating> partialDataTruncator;
@property (nonatomic, strong, readonly) id<AMADataTruncating> fullDataTruncator;

@end

@implementation AMAEventValueFactory

- (instancetype)init
{
    return [self initWithStringTruncator:[AMATruncatorsFactory eventStringValueTruncator]
                    partialDataTruncator:[AMATruncatorsFactory eventBinaryValueTruncator]
                       fullDataTruncator:[AMATruncatorsFactory fullValueTruncator]];
}

- (instancetype)initWithStringTruncator:(id<AMAStringTruncating>)stringTruncator
                   partialDataTruncator:(id<AMADataTruncating>)partialDataTruncator
                      fullDataTruncator:(id<AMADataTruncating>)fullDataTruncator
{
    self = [super init];
    if (self != nil) {
        _stringTruncator = stringTruncator;
        _partialDataTruncator = partialDataTruncator;
        _fullDataTruncator = fullDataTruncator;
    }
    return self;
}

#pragma mark - Public -

- (id<AMAEventValueProtocol>)stringEventValue:(NSString *)value bytesTruncated:(NSUInteger *)bytesTruncated
{
    NSString *truncatedValue = [self.stringTruncator truncatedString:value onTruncation:^(NSUInteger truncated) {
        if (bytesTruncated != NULL) {
            *bytesTruncated += truncated;
        }
    }];
    return [[AMAStringEventValue alloc] initWithValue:truncatedValue];
}

- (id<AMAEventValueProtocol>)binaryEventValue:(NSData *)value
                                      gZipped:(BOOL)gZipped
                               bytesTruncated:(NSUInteger *)bytesTruncated
{
    id<AMADataTruncating> truncator = gZipped ? self.fullDataTruncator : self.partialDataTruncator;
    NSData *truncatedValue = [truncator truncatedData:value onTruncation:^(NSUInteger truncated) {
        if (bytesTruncated != NULL) {
            *bytesTruncated += truncated;
        }
    }];
    return truncatedValue != nil
        ? [[AMABinaryEventValue alloc] initWithData:truncatedValue gZipped:gZipped]
        : nil;
}

- (id<AMAEventValueProtocol>)fileEventValue:(NSData *)value
                                   fileName:(NSString *)fileName
                                    gZipped:(BOOL)gZipped
                             encryptionType:(AMAEventEncryptionType)encryptionType
                             truncationType:(AMAEventValueFactoryTruncationType)truncationType
                             bytesTruncated:(NSUInteger *)bytesTruncated
                                      error:(NSError **)error
{
    
    AMAEventEncryptionType fileValueEncryptionType = encryptionType;
    AMAEventEncryptionType fileStorageEncryptionType = encryptionType;
    
    if (gZipped) {
        fileValueEncryptionType = AMAEventEncryptionTypeGZip;
        fileStorageEncryptionType = AMAEventEncryptionTypeNoEncryption;
    }
    
    return [self fileEventValue:value
                       fileName:fileName
      fileStorageEncryptionType:fileStorageEncryptionType
        fileValueEncryptionType:fileValueEncryptionType
                 truncationType:truncationType
                 bytesTruncated:bytesTruncated
                          error:error];
}

#pragma mark - Private -

- (id<AMAEventValueProtocol>)fileEventValue:(NSData *)value
                                   fileName:(NSString *)fileName
                  fileStorageEncryptionType:(AMAEventEncryptionType)fileStorageEncType
                    fileValueEncryptionType:(AMAEventEncryptionType)fileValueEncType
                             truncationType:(AMAEventValueFactoryTruncationType)truncationType
                             bytesTruncated:(NSUInteger *)bytesTruncated
                                      error:(NSError **)error
{
    id<AMAEventValueProtocol> result = nil;
    
    id<AMADataTruncating> truncator = [self truncatorForType:truncationType];
    NSData *truncatedValue = [truncator truncatedData:value onTruncation:^(NSUInteger truncated) {
        if (bytesTruncated != NULL) {
            *bytesTruncated += truncated;
        }
    }];
    
    if (truncatedValue.length > 0) {
        NSString *filePath = [AMAFileUtility pathForFullFileName:fileName];
        id<AMAFileStorage> fileStorage = [AMAEncryptedFileStorageFactory fileStorageForEncryptionType:fileStorageEncType
                                                                                             filePath:filePath];
        NSError *internalError = nil;
        [fileStorage writeData:truncatedValue error:&internalError];
        if (internalError == nil) {
            result = [[AMAFileEventValue alloc] initWithRelativeFilePath:fileName encryptionType:fileValueEncType];
        }
        else {
            [AMAErrorUtilities fillError:error withError:internalError];
        }
    }
    return result;
}

- (id<AMADataTruncating>)truncatorForType:(AMAEventValueFactoryTruncationType)truncationType
{
    switch (truncationType) {
        case AMAEventValueFactoryTruncationTypePartial:
            return self.partialDataTruncator;
            
        case AMAEventValueFactoryTruncationTypeFull:
            return self.fullDataTruncator;
    }
}

@end
