
#import "AMAProhibitingAttributeUpdateValidator.h"

@interface AMAProhibitingAttributeUpdateValidator ()

@property (nonatomic, copy, readonly) AMAProhibitingAttributeUpdateLogBlock logBlock;

@end

@implementation AMAProhibitingAttributeUpdateValidator

- (instancetype)initWithLogBlock:(AMAProhibitingAttributeUpdateLogBlock)logBlock
{
    self = [super init];
    if (self != nil) {
        _logBlock = [logBlock copy];
    }
    return self;
}

- (BOOL)validateUpdate:(AMAAttributeUpdate *)update model:(AMAUserProfileModel *)model
{
    if (self.logBlock != nil) {
        self.logBlock(update);
    }
    return NO;
}

@end
