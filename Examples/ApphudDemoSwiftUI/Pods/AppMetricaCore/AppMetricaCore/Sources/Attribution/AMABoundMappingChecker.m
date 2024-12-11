
#import "AMABoundMapping.h"
#import "AMABoundMappingChecker.h"

@implementation AMABoundMappingChecker

- (NSNumber *)check:(NSDecimalNumber *)number mappings:(NSArray<AMABoundMapping *> *)mappings
{
    NSNumber *result = nil;
    NSUInteger index = [mappings indexOfObject:[[AMABoundMapping alloc] initWithBound:number value:@0]
                                 inSortedRange:NSMakeRange(0, [mappings count])
                                       options:NSBinarySearchingInsertionIndex
                               usingComparator:^(id obj1, id obj2) {
                                   return [obj1 compare:obj2];
                               }];
    if (index >= mappings.count) {
        result = mappings.lastObject.value;
    } else {
        if ([mappings[index].bound isEqualToNumber:number]) {
            result = mappings[index].value;
        } else {
            if (index > 0) {
                result = mappings[index - 1].value;
            }
        }
    }
    return result;
}


@end
