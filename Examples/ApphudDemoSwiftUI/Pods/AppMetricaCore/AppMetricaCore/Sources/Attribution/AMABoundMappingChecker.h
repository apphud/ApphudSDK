
#import <Foundation/Foundation.h>

@class AMABoundMapping;

@interface AMABoundMappingChecker : NSObject

- (NSNumber *)check:(NSDecimalNumber *)number mappings:(NSArray<AMABoundMapping *> *)mappings;

@end
