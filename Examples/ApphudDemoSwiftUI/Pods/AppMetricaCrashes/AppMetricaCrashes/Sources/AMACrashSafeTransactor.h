
#import <Foundation/Foundation.h>

typedef NSString * (^AMACrashSafeTransactorRollbackBlock)(id context);

@protocol AMATransactionReporter <NSObject>
- (void)reportFailedTransactionWithID:(NSString *)transactionID
                            ownerName:(NSString *)ownerName
                      rollbackContent:(NSString *)rollbackContent
                    rollbackException:(NSException *)rollbackException
                       rollbackFailed:(BOOL)rollbackFailed;
@end


@interface AMACrashSafeTransactor : NSObject

@property (nonatomic, strong, readonly) id<AMATransactionReporter> reporter;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithReporter:(id<AMATransactionReporter>)reporter;

- (void)processTransactionWithID:(NSString *)transactionID
                            name:(NSString *)name
                     transaction:(dispatch_block_t)transaction;

- (void)processTransactionWithID:(NSString *)transactionID
                            name:(NSString *)name
                     transaction:(dispatch_block_t)transaction
                        rollback:(AMACrashSafeTransactorRollbackBlock)rollback;

- (void)processTransactionWithID:(NSString *)transactionID
                            name:(NSString *)name
                 rollbackContext:(id<NSCoding>)rollBackContext
                     transaction:(dispatch_block_t)transaction
                        rollback:(AMACrashSafeTransactorRollbackBlock)rollback;
                 

@end
