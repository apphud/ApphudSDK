
#import <Foundation/Foundation.h>

@class AMAStartupClientIdentifier;

@interface AMAStartupClientIdentifierFactory : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (AMAStartupClientIdentifier *)startupClientIdentifier;

@end
