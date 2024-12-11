
#import "AMALogMiddleware.h"

@interface AMAASLLogMiddleware : NSObject <AMALogMiddleware>

- (instancetype)initWithFacility:(NSString *)sender;

@end
