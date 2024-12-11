
#import <Foundation/Foundation.h>

@interface AMACrashSafeTransactionLock : NSObject

@property (nonatomic, copy, readonly) NSString *lockOwnerName;
@property (nonatomic, assign, readonly) BOOL transactionLocked;
@property (nonatomic, readonly) id rollbackContext;
@property (nonatomic, assign) BOOL rollbackLocked;
@property (nonatomic, assign) BOOL shouldBeReported;

- (instancetype)initWithTransactionID:(NSString *)transactionID name:(NSString *)name;
- (instancetype)initWithTransactionID:(NSString *)transactionID
                                 name:(NSString *)name
                      rollbackContext:(id<NSCoding>)rollbackContext;

- (void)lockTransaction;
- (void)releaseTransaction;

@end
