
#import <Foundation/Foundation.h>

@interface AMAEventTypeResolver : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (BOOL)isEventTypeReserved:(NSUInteger)eventType;

@end
