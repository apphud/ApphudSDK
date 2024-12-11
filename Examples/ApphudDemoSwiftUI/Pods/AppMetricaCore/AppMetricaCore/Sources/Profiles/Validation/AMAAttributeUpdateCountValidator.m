
#import "AMAAttributeUpdateCountValidator.h"
#import "AMAUserProfileLogger.h"
#import "AMAUserProfileModel.h"
#import "AMAAttributeUpdate.h"
#import "AMAAttributeKey.h"

static NSUInteger const kAMAAttributesCountLimit = 100;

@interface AMAAttributeUpdateCountValidator ()

@property (nonatomic, assign, readonly) NSUInteger countLimit;

@end

@implementation AMAAttributeUpdateCountValidator

- (instancetype)init
{
    return [self initWithCountLimit:kAMAAttributesCountLimit];
}

- (instancetype)initWithCountLimit:(NSUInteger)countLimit
{
    self = [super init];
    if (self != nil) {
        _countLimit = countLimit;
    }
    return self;
}

- (BOOL)validateUpdate:(AMAAttributeUpdate *)update model:(AMAUserProfileModel *)model
{
    if (update.custom == NO) {
        return YES;
    }
    AMAAttributeKey *key = [[AMAAttributeKey alloc] initWithName:update.name type:update.type];
    BOOL isValid = model.attributes[key] != nil || model.customAttributeKeysCount < self.countLimit;
    if (isValid == NO) {
        [AMAUserProfileLogger logTooManyCustomAttributesWithAttributeName:update.name];
    }
    return isValid;
}

@end
