
#import <Foundation/Foundation.h>
#import "AMAJSONSerializable.h"

@interface AMABoundMapping : NSObject <AMAJSONSerializable>

@property (nonatomic, strong, readonly) NSDecimalNumber *bound;
@property (nonatomic, assign, readonly) NSNumber *value;

- (instancetype)initWithBound:(NSDecimalNumber *)bound value:(NSNumber *)value;
- (NSComparisonResult)compare:(AMABoundMapping *)other;

@end
