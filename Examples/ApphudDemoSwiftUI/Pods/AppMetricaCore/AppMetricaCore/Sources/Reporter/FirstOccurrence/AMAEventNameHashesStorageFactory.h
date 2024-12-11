
#import <Foundation/Foundation.h>

@class AMAEventNameHashesStorage;

extern NSString *const kAMAEventHashesFileName;

@interface AMAEventNameHashesStorageFactory : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (AMAEventNameHashesStorage *)storageForApiKey:(NSString *)apiKey main:(BOOL)main;

@end
