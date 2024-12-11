
#import "AMALogMiddleware.h"

@interface AMATTYLogMiddleware : NSObject <AMALogMiddleware>

- (instancetype)initWithOutputDescriptor:(int)descriptor;

@end
