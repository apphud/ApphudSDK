
#import "AMAUserProfile+Internal.h"

@implementation AMAUserProfile

- (instancetype)init
{
    return [self initWithUpdates:[NSArray array]];
}

- (instancetype)initWithUpdates:(NSArray<AMAUserProfileUpdate *> *)updates
{
    self = [super init];
    if (self != nil) {
        _mutableUpdates = [updates mutableCopy] ?: [NSMutableArray array];
    }
    return self;
}

- (NSArray<AMAUserProfileUpdate *> *)updates
{
    return [self.mutableUpdates copy];
}

- (instancetype)copyWithZone:(nullable NSZone *)zone
{
    return self;
}

- (instancetype)mutableCopyWithZone:(nullable NSZone *)zone
{
    return [[AMAMutableUserProfile alloc] initWithUpdates:self.updates];
}

@end
