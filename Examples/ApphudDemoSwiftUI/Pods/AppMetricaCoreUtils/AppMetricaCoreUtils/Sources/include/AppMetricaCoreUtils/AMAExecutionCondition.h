
#import <Foundation/Foundation.h>

NS_SWIFT_NAME(ExecutionCondition)
@protocol AMAExecutionCondition <NSObject>

- (BOOL)shouldExecute;

@end
