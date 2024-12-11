
#import "AMABinaryEventValue.h"

@implementation AMABinaryEventValue

- (instancetype)initWithData:(NSData *)data
                     gZipped:(BOOL)gZipped
{
    self = [super init];
    if (self != nil) {
        _data = [data copy];
        _gZipped = gZipped;
    }
    return self;
}

- (AMAEventEncryptionType)encryptionType
{
    return self.gZipped ? AMAEventEncryptionTypeGZip : AMAEventEncryptionTypeNoEncryption;
}

- (BOOL)empty
{
    return self.data.length == 0;
}

- (NSData *)dataWithError:(NSError **)error
{
    return self.data;
}

- (NSData *)gzippedDataWithError:(NSError **)error
{
    return self.gZipped ? self.data : nil;
}

@end
