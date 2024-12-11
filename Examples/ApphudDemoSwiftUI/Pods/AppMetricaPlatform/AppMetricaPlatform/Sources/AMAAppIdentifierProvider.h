
#import <Foundation/Foundation.h>

@interface AMAAppIdentifierProvider : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (NSString *)appIdentifierPrefix;

@end
