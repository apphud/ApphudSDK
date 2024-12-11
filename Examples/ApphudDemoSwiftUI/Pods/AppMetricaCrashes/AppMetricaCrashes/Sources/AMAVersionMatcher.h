
#import <Foundation/Foundation.h>

@interface AMAVersionMatcher : NSObject

/**
 Ruby's `~>` a.k.a. "twiddle-wakka" analogue.
 */
+ (BOOL)isVersion:(NSString *)version matchesPessimisticConstraint:(NSString *)constraint;

@end
