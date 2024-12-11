#import "AMACrashSafeTransactor.h"

#import "AMACrashSafeTransactionLock.h"
#import "AMACrashSafeTransactionRollbackResult.h"

@implementation AMACrashSafeTransactor

- (instancetype)initWithReporter:(id<AMATransactionReporter>)reporter
{
    self = [super init];
    if (self != nil) {
        _reporter = reporter;
    }
    return self;
}

#pragma mark - Public -

- (void)processTransactionWithID:(NSString *)transactionID
                            name:(NSString *)name
                     transaction:(dispatch_block_t)transaction
{
    [self processTransactionWithID:transactionID name:name transaction:transaction rollback:nil];
}

- (void)processTransactionWithID:(NSString *)transactionID
                            name:(NSString *)name
                     transaction:(dispatch_block_t)transaction
                        rollback:(AMACrashSafeTransactorRollbackBlock)rollback
{
    [self processTransactionWithID:transactionID
                              name:name
                   rollbackContext:nil
                       transaction:transaction
                          rollback:rollback];
}

- (void)processTransactionWithID:(NSString *)transactionID
                            name:(NSString *)name
                 rollbackContext:(id<NSCoding>)rollbackContext
                     transaction:(dispatch_block_t)transaction
                        rollback:(AMACrashSafeTransactorRollbackBlock)rollback
{
    AMACrashSafeTransactionLock *lock =
        [[AMACrashSafeTransactionLock alloc] initWithTransactionID:transactionID
                                                              name:name
                                                   rollbackContext:rollbackContext];

    if (lock.transactionLocked) {
        AMACrashSafeTransactionRollbackResult *rollbackResult = [self rollbackTransactionWithID:transactionID
                                                                                           lock:lock
                                                                                       rollback:rollback];
        [self reportFailedTransactionWithID:transactionID
                                       lock:lock
                             rollbackResult:rollbackResult];
        if (rollbackResult.completed) {
            [lock releaseTransaction];
        }
    }
    else if (transaction != nil) {
        [lock lockTransaction];
        transaction();
        [lock releaseTransaction];
    }
}

#pragma mark - Private -

- (AMACrashSafeTransactionRollbackResult *)rollbackTransactionWithID:(NSString *)transactionID
                                                                lock:(AMACrashSafeTransactionLock *)lock
                                                            rollback:(AMACrashSafeTransactorRollbackBlock)rollback
{
    BOOL completed = NO;
    NSException *rollbackException = nil;
    NSString *rollbackContent = nil;

    if (lock.rollbackLocked == NO && rollback != nil) {
        @try {
            lock.rollbackLocked = YES;
            rollbackContent = rollback(lock.rollbackContext);
            lock.rollbackLocked = NO;
            completed = YES;
        }
        @catch (NSException *exception) {
            rollbackException = exception;
        }
    }

    return [[AMACrashSafeTransactionRollbackResult alloc] initWithCompleted:completed
                                                                    content:rollbackContent
                                                                  exception:rollbackException];
}

- (void)reportFailedTransactionWithID:(NSString *)transactionID
                                 lock:(AMACrashSafeTransactionLock *)lock
                       rollbackResult:(AMACrashSafeTransactionRollbackResult *)rollbackResult
{
    if (lock.shouldBeReported) {
        [self.reporter reportFailedTransactionWithID:transactionID
                                           ownerName:lock.lockOwnerName
                                     rollbackContent:rollbackResult.content
                                   rollbackException:rollbackResult.exception
                                      rollbackFailed:rollbackResult.exception != nil];
        lock.shouldBeReported = NO;
    }
}

@end
