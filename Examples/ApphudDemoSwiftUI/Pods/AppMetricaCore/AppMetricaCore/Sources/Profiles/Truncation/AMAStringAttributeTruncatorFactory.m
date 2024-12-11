
#import "AMACore.h"
#import "AMAStringAttributeTruncatorFactory.h"
#import "AMAStringAttributeTruncationProvider.h"

static NSUInteger const kAMAPredefinedStringAttributeMaxLength = 100;
static NSUInteger const kAMACustomStringAttributeMaxLength = 200;

@implementation AMAStringAttributeTruncatorFactory

+ (AMAStringAttributeTruncationProvider *)nameTruncationProvider
{
    return [self providerWithMaxLength:kAMAPredefinedStringAttributeMaxLength];
}

+ (AMAStringAttributeTruncationProvider *)genderTruncationProvider
{
    return [self permissiveProvider];
}

+ (AMAStringAttributeTruncationProvider *)birthDateTruncationProvider
{
    return [self permissiveProvider];
}

+ (AMAStringAttributeTruncationProvider *)customStringTruncationProvider
{
    return [self providerWithMaxLength:kAMACustomStringAttributeMaxLength];
}

+ (AMAStringAttributeTruncationProvider *)providerWithMaxLength:(NSUInteger)maxLength
{
    id<AMAStringTruncating> underlyingTruncator = [[AMALengthStringTruncator alloc] initWithMaxLength:maxLength];
    return [[AMAStringAttributeTruncationProvider alloc] initWithUnderlyingTruncator:underlyingTruncator];
}

+ (AMAStringAttributeTruncationProvider *)permissiveProvider
{
    id<AMAStringTruncating> underlyingTruncator = [[AMAPermissiveTruncator alloc] init];
    return [[AMAStringAttributeTruncationProvider alloc] initWithUnderlyingTruncator:underlyingTruncator];
}

@end
