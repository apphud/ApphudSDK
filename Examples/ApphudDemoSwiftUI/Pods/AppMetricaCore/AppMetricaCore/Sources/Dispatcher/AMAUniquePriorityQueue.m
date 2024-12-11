
#import "AMAUniquePriorityQueue.h"

@interface AMAUniquePriorityQueue ()

@property (nonatomic, strong, readonly) NSMutableOrderedSet *regularApiKeysQueue;
@property (nonatomic, strong, readonly) NSMutableOrderedSet *forcedApiKeysQueue;

@end

@implementation AMAUniquePriorityQueue

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _forcedApiKeysQueue = [NSMutableOrderedSet orderedSet];
        _regularApiKeysQueue = [NSMutableOrderedSet orderedSet];
    }
    return self;
}

- (void)push:(id)object prioritized:(BOOL)isPrioritized
{
    if (isPrioritized) {
        [self.regularApiKeysQueue removeObject:object];
        [self.forcedApiKeysQueue addObject:object];
    }
    else {
        if ([self.forcedApiKeysQueue containsObject:object] == NO) {
            [self.regularApiKeysQueue addObject:object];
        }
    }
}

- (id)popPrioritized:(BOOL *)isPrioritized
{
    id object = [self peekPrioritized:isPrioritized];

    [self.forcedApiKeysQueue removeObject:object];
    [self.regularApiKeysQueue removeObject:object];

    return object;
}

- (id)peekPrioritized:(BOOL *)isPrioritized
{
    id object = self.forcedApiKeysQueue.firstObject;
    if (object != nil) {
        if (isPrioritized != NULL) {
            *isPrioritized = YES;
        }
    }
    else {
        object = self.regularApiKeysQueue.firstObject;
        if (object != nil) {
            if (isPrioritized != NULL) {
                *isPrioritized = NO;
            }
        }
    }
    return object;
}

- (NSUInteger)count
{
    return self.regularApiKeysQueue.count + self.forcedApiKeysQueue.count;
}

#if AMA_ALLOW_DESCRIPTIONS
- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithString:@"(\n"];
    for (id object in self.forcedApiKeysQueue) {
        [description appendFormat:@"    %@,\n", object];
    }
    for (id object in self.regularApiKeysQueue) {
        [description appendFormat:@"    %@,\n", object];
    }
    [description appendString:@")\n"];
    return [description copy];
}
#endif

@end
