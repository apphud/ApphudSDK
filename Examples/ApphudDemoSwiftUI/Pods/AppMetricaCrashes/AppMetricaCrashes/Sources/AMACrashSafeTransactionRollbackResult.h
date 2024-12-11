
#import <Foundation/Foundation.h>

@interface AMACrashSafeTransactionRollbackResult : NSObject

@property (nonatomic, assign, readonly) BOOL completed;
@property (nonatomic, copy, readonly) NSString *content;
@property (nonatomic, strong, readonly) NSException *exception;

- (instancetype)initWithCompleted:(BOOL)completed
                          content:(NSString *)content
                        exception:(NSException *)exception;

@end
