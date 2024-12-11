
#import <Foundation/Foundation.h>

@interface AMAUUIDProvider : NSObject

+ (instancetype)sharedInstance;
- (NSString *)retrieveUUID;

@end
