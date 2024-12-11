
#import "AMABinaryImage.h"

@implementation AMABinaryImage

- (instancetype)initWithName:(NSString *)name
                        UUID:(NSString *)UUID
                     address:(NSUInteger)address
                        size:(NSUInteger)size
                   vmAddress:(NSUInteger)vmAddress
                     cpuType:(NSUInteger)cpuType
                  cpuSubtype:(NSUInteger)cpuSubtype
                majorVersion:(int32_t)majorVersion
                minorVersion:(int32_t)minorVersion
             revisionVersion:(int32_t)revisionVersion
            crashInfoMessage:(NSString *)crashInfoMessage
           crashInfoMessage2:(NSString *)crashInfoMessage2
{
    self = [super init];
    if (self != nil) {
        _name = [name copy];
        _UUID = [UUID copy];
        _address = address;
        _size = size;
        _vmAddress = vmAddress;
        _cpuType = cpuType;
        _cpuSubtype = cpuSubtype;
        _majorVersion = majorVersion;
        _minorVersion = minorVersion;
        _revisionVersion = revisionVersion;
        _crashInfoMessage = [crashInfoMessage copy];
        _crashInfoMessage2 = [crashInfoMessage2 copy];
    }
    return self;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

#pragma mark - NSObject

- (NSUInteger)hash
{
    return self.address;
}

- (NSComparisonResult)compare:(AMABinaryImage *)otherImage
{
    if (self.address < otherImage.address) {
        return NSOrderedAscending;
    }
    else if (self.address > otherImage.address) {
        return NSOrderedDescending;
    }
    else {
        return NSOrderedSame;
    }
}

- (BOOL)isEqual:(id)object
{
    BOOL isEqual = [object isKindOfClass:[self class]];
    if (isEqual) {
        AMABinaryImage *otherImage = object;
        isEqual = otherImage.address == self.address;
        isEqual = isEqual && otherImage.size == self.size;
        isEqual = isEqual && otherImage.vmAddress == self.vmAddress;
        isEqual = isEqual && otherImage.cpuType == self.cpuType;
        isEqual = isEqual && otherImage.cpuSubtype == self.cpuSubtype;
        isEqual = isEqual && (otherImage.UUID == self.UUID || [otherImage.UUID isEqualToString:self.UUID]);
        isEqual = isEqual && (otherImage.name == self.name || [otherImage.name isEqualToString:self.name]);
        isEqual = isEqual && otherImage.majorVersion == self.majorVersion;
        isEqual = isEqual && otherImage.minorVersion == self.minorVersion;
        isEqual = isEqual && otherImage.revisionVersion == self.revisionVersion;
        isEqual = isEqual && (otherImage.crashInfoMessage == self.crashInfoMessage
                              || [otherImage.crashInfoMessage isEqual:self.crashInfoMessage]);
        isEqual = isEqual && (otherImage.crashInfoMessage2 == self.crashInfoMessage2
                              || [otherImage.crashInfoMessage2 isEqual:self.crashInfoMessage2]);
    }
    return isEqual;
}

#if AMA_ALLOW_DESCRIPTIONS
- (NSString *)description
{
    unsigned long beginAddress = self.address;
    unsigned long endAddress = self.address + self.size;
    unsigned long size = self.size;
    return [NSString stringWithFormat:@"%#10lx +%lu : %#10lx (%@)", beginAddress, size, endAddress, self.name];
}
#endif

@end
