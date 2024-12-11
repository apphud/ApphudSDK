
#import <Foundation/Foundation.h>

@class AMABoundMapping;
@class AMABoundMappingChecker;

@interface AMAEventSumBoundBasedModelHelper : NSObject

- (instancetype)initWithBoundMappingChecker:(AMABoundMappingChecker *)boundMappingChecker;
- (NSNumber *)calculateNewConversionValue:(NSDecimalNumber *)sumAddition
                            boundMappings:(NSArray<AMABoundMapping *> *)boundMappings;

@end
