
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(RollbackHolder)
@interface AMARollbackHolder : NSObject

@property (nonatomic, assign) BOOL rollback;

- (void)subscribeOnRollback:(dispatch_block_t)block;
- (void)complete;

@end

NS_ASSUME_NONNULL_END
