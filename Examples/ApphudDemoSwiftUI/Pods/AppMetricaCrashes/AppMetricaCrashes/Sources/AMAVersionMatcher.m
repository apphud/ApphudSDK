
#import "AMAVersionMatcher.h"

@implementation AMAVersionMatcher

+ (BOOL)isVersion:(NSString *)version matchesPessimisticConstraint:(NSString *)constraint
{
    NSArray* versionOneComp = [version componentsSeparatedByString:@"."];
    NSArray* constraintComp = [constraint componentsSeparatedByString:@"."];

    NSUInteger pos = 0;

    while (versionOneComp.count > pos || constraintComp.count > pos) {
        NSInteger v1 = versionOneComp.count > pos ? [versionOneComp[pos] integerValue] : 0;
        NSInteger v2 = constraintComp.count > pos ? [constraintComp[pos] integerValue] : v1;
        if (v1 == v2) {
            pos++;
        }
        else {
            return NO;
        }
    }

    return YES;
}

@end
