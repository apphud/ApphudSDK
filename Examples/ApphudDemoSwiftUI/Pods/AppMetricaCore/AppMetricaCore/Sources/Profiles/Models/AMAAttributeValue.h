
#import <Foundation/Foundation.h>
#import "AMAAttributeType.h"

@interface AMAAttributeValue : NSObject

@property (nonatomic, strong) NSNumber *setIfUndefined;
@property (nonatomic, strong) NSNumber *reset;

@property (nonatomic, copy) NSString *stringValue;
@property (nonatomic, strong) NSNumber *numberValue;
@property (nonatomic, strong) NSNumber *counterValue;
@property (nonatomic, strong) NSNumber *boolValue;

@end
