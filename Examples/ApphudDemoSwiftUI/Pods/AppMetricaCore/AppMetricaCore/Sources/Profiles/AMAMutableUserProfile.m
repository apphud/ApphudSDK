
#import "AMAUserProfile+Internal.h"

@implementation AMAMutableUserProfile

- (void)apply:(AMAUserProfileUpdate *)update
{
    if (update != nil) {
        @synchronized (self) {
            [self.mutableUpdates addObject:update];
        }
    }
}

- (void)applyFromArray:(NSArray<AMAUserProfileUpdate *> *)updatesArray
{
    if (updatesArray.count > 0) {
        @synchronized (self) {
            [self.mutableUpdates addObjectsFromArray:updatesArray];
        }
    }
}

- (NSArray<AMAUserProfileUpdate *> *)updates
{
    @synchronized (self) {
        return [super updates];
    }
}

- (id)copyWithZone:(nullable NSZone *)zone
{
    @synchronized (self) {
        return [[AMAUserProfile alloc] initWithUpdates:[self.mutableUpdates copy]];
    }
}

- (id)mutableCopyWithZone:(nullable NSZone *)zone
{
    @synchronized (self) {
        return [super mutableCopyWithZone:zone];
    }
}

@end
