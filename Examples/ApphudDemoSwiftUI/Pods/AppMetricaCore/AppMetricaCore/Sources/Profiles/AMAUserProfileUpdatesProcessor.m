
#import "AMACore.h"
#import "AMAUserProfileUpdatesProcessor.h"
#import "AMAUserProfileModel.h"
#import "AMAUserProfileUpdate.h"
#import "AMAAttributeUpdateValidating.h"
#import "AMAAttributeUpdate.h"
#import "AMAUserProfileModelSerializer.h"
#import "AMAErrorsFactory.h"

@interface AMAUserProfileUpdatesProcessor ()

@property (nonatomic, strong, readonly) AMAUserProfileModelSerializer *serializer;

@end

@implementation AMAUserProfileUpdatesProcessor

- (instancetype)init
{
    return [self initWithSerializer:[[AMAUserProfileModelSerializer alloc] init]];
}

- (instancetype)initWithSerializer:(AMAUserProfileModelSerializer *)serializer
{
    self = [super init];
    if (self != nil) {
        _serializer = serializer;
    }
    return self;
}

- (BOOL)validateUserProfileUpdate:(AMAUserProfileUpdate *)update model:(AMAUserProfileModel *)model
{
    BOOL isValid = YES;
    for (id<AMAAttributeUpdateValidating> validator in update.validators) {
        if ([validator validateUpdate:update.attributeUpdate model:model] == NO) {
            isValid = NO;
            break;
        }
    }
    return isValid;
}

- (BOOL)applyUpdates:(NSArray<AMAUserProfileUpdate *> *)updates toModel:(AMAUserProfileModel *)model
{
    BOOL isAnyAttributeApplied = NO;
    for (AMAUserProfileUpdate *update in updates) {
        if ([self validateUserProfileUpdate:update model:model]) {
            [update.attributeUpdate applyToModel:model];
            isAnyAttributeApplied = YES;
        }
    }
    return isAnyAttributeApplied;
}

- (NSData *)dataWithUpdates:(NSArray<AMAUserProfileUpdate *> *)updates error:(NSError *__autoreleasing *)error
{
    NSData *data = nil;
    AMAUserProfileModel *model = [[AMAUserProfileModel alloc] init];
    if ([self applyUpdates:updates toModel:model]) {
        data = [self.serializer dataWithModel:model];
    }
    else {
        [AMAErrorUtilities fillError:error withError:[AMAErrorsFactory emptyUserProfileError]];
    }
    return data;
}

@end
