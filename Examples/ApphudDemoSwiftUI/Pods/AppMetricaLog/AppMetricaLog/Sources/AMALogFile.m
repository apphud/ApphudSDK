
#import "AMALogFile.h"

@interface AMALogFile ()

@property (nonatomic, copy, readwrite) NSString *fileName;
@property (nonatomic, strong, readwrite) NSNumber *serialNumber;

@end

@implementation AMALogFile

- (instancetype)initWithFileName:(NSString *)fileName serialNumber:(NSNumber *)serialNumber
{
    NSParameterAssert(fileName);
    NSParameterAssert(serialNumber);

    self = [super init];
    if (self) {
        _fileName = [fileName copy];
        _serialNumber = serialNumber;
    }

    return self;
}

- (BOOL)isEqual:(AMALogFile *)other
{
    if (other == self) {
        return YES;
    }
    if (other == nil || [[other class] isEqual:[self class]] == NO) {
        return NO;
    }
    if (self.fileName != other.fileName && [self.fileName isEqualToString:other.fileName] == NO) {
        return NO;
    }
    if (self.serialNumber != other.serialNumber && [self.serialNumber isEqualToNumber:other.serialNumber] == NO) {
        return NO;
    }
    return YES;
}

@end
