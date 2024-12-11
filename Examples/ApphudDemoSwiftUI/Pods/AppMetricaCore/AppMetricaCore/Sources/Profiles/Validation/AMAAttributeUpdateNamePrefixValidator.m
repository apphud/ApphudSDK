
#import "AMAAttributeUpdateNamePrefixValidator.h"
#import "AMAUserProfileLogger.h"
#import "AMAAttributeNameProvider.h"
#import "AMAAttributeUpdate.h"

@interface AMAAttributeUpdateNamePrefixValidator ()

@property (nonatomic, copy, readonly) NSString *forbiddenPrefix;

@end

@implementation AMAAttributeUpdateNamePrefixValidator

- (instancetype)init
{
    return [self initWithForbiddenPrefix:kAMAAttributeNameProviderPredefinedAttributePrefix];
}

- (instancetype)initWithForbiddenPrefix:(NSString *)forbiddenPrefix
{
    self = [super init];
    if (self != nil) {
        _forbiddenPrefix = [forbiddenPrefix copy];
    }
    return self;
}

- (BOOL)validateUpdate:(AMAAttributeUpdate *)update model:(AMAUserProfileModel *)model
{
    BOOL hasForbiddenPrefix = [update.name hasPrefix:self.forbiddenPrefix];
    if (hasForbiddenPrefix) {
        [AMAUserProfileLogger logForbiddenAttributeNamePrefixWithName:update.name
                                                      forbiddenPrefix:self.forbiddenPrefix];
    }
    return hasForbiddenPrefix == NO;
}

@end
