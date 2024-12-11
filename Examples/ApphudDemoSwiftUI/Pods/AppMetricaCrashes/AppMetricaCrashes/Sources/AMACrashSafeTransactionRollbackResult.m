
#import "AMACrashSafeTransactionRollbackResult.h"

@implementation AMACrashSafeTransactionRollbackResult

- (instancetype)initWithCompleted:(BOOL)completed
                          content:(NSString *)content
                        exception:(NSException *)exception
{
    self = [super init];
    if (self != nil) {
        _completed = completed;
        _content = [content copy];
        _exception = exception;
    }
    return self;
}

@end
