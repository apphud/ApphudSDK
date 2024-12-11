
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>

@interface AMARollbackHolder ()

@property (nonatomic, strong, readonly) NSMutableArray *blocks;

@end

@implementation AMARollbackHolder

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _blocks = [NSMutableArray array];
    }
    return self;
}

- (void)subscribeOnRollback:(dispatch_block_t)block
{
    if (block == nil) {
        return;
    }
    [self.blocks addObject:[block copy]];
}

- (void)complete
{
    if (self.rollback) {
        [self.blocks enumerateObjectsWithOptions:NSEnumerationReverse
                                      usingBlock:^(dispatch_block_t block, NSUInteger idx, BOOL *stop) {
                                          block();
                                      }];
    }
}

@end
