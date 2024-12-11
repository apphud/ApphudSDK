
#import <Foundation/Foundation.h>

@interface AMAUniquePriorityQueue : NSObject

@property(nonatomic, assign, readonly) NSUInteger count;

- (void)push:(id)object prioritized:(BOOL)isPrioritized;
- (id)popPrioritized:(BOOL *)isPrioritized;
- (id)peekPrioritized:(BOOL *)isPrioritized;

@end
