
#import "AMAEncryptedFileStorage.h"

@interface AMAEncryptedFileStorage ()

@property (nonatomic, strong, readonly) id<AMAFileStorage> underlyingStorage;
@property (nonatomic, strong, readonly) id<AMADataEncoding> encoder;

@end

@implementation AMAEncryptedFileStorage

- (instancetype)initWithUnderlyingStorage:(id<AMAFileStorage>)underlyingStorage
                                  encoder:(id<AMADataEncoding>)encoder
{
    self = [super init];
    if (self != nil) {
        _underlyingStorage = underlyingStorage;
        _encoder = encoder;
    }
    return self;
}

- (BOOL)fileExists
{
    return self.underlyingStorage.fileExists;
}

- (NSData *)readDataWithError:(NSError **)error
{
    NSData *result = nil;
    NSData *encodedData = [self.underlyingStorage readDataWithError:error];
    if (encodedData != nil) {
        result = [self.encoder decodeData:encodedData error:error];
    }
    return result;
}

- (BOOL)writeData:(NSData *)data error:(NSError **)error
{
    BOOL result = NO;
    NSData *encodedData = [self.encoder encodeData:data error:error];
    if (encodedData != nil) {
        result = [self.underlyingStorage writeData:encodedData error:error];
    }
    return result;
}

- (BOOL)deleteFileWithError:(NSError **)error
{
    return [self.underlyingStorage deleteFileWithError:error];
}

#if AMA_ALLOW_DESCRIPTIONS
- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ encoder: %@, underlying: %@",
                                      [super description], self.encoder, self.underlyingStorage];
}
#endif

@end
