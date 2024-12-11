
#import "AMACore.h"
#import "AMAAttributeUpdateNameLengthValidator.h"
#import "AMAUserProfileLogger.h"
#import "AMAAttributeUpdate.h"

static NSUInteger const kAMAAttributeNameLengthLimit = 200;

@interface AMAAttributeUpdateNameLengthValidator ()

@property (nonatomic, assign, readonly) NSUInteger lengthLimit;

@end

@implementation AMAAttributeUpdateNameLengthValidator

- (instancetype)init
{
    return [self initWithLengthLimit:kAMAAttributeNameLengthLimit];
}

- (instancetype)initWithLengthLimit:(NSUInteger)lengthLimit
{
    self = [super init];
    if (self != nil) {
        _lengthLimit = lengthLimit;
    }
    return self;
}

- (BOOL)validateUpdate:(AMAAttributeUpdate *)update model:(AMAUserProfileModel *)model
{
    BOOL isOutOfLimits = update.name.length > self.lengthLimit;
    if (isOutOfLimits) {
        [AMAUserProfileLogger logAttributeNameTooLong:update.name];
    }
    return isOutOfLimits == NO;
}

@end
