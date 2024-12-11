
#import <Foundation/Foundation.h>

NS_SWIFT_NAME(DateProviding)
@protocol AMADateProviding <NSObject>

@required

- (NSDate *)currentDate;

@end
