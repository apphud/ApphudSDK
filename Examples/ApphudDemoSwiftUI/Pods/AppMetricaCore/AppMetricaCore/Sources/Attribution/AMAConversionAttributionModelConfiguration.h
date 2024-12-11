
#import <Foundation/Foundation.h>
#import "AMAJSONSerializable.h"

@class AMAAttributionMapping;

@interface AMAConversionAttributionModelConfiguration : NSObject <AMAJSONSerializable>

@property (nonatomic, strong, readonly) NSArray<AMAAttributionMapping *> *mappings;

- (instancetype)initWithMappings:(NSArray<AMAAttributionMapping *> *)mappings;

@end
