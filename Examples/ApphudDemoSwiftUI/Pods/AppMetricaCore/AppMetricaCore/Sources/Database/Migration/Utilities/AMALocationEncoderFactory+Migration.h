
#import <Foundation/Foundation.h>
#import "AMALocationEncoderFactory.h"

@interface AMALocationEncoderFactory (Migration)

+ (id<AMADataEncoding>)migrationEncoder;

@end
