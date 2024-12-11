
#import <Foundation/Foundation.h>

@interface AMADate : NSObject

@property (nonatomic, strong) NSDate *deviceDate;
@property (nonatomic, strong) NSNumber *serverTimeOffset;

@end
