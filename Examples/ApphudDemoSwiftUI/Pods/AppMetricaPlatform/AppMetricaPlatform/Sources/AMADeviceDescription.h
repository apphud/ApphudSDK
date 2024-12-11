
#import <Foundation/Foundation.h>

@interface AMADeviceDescription : NSObject

+ (NSString *)appIdentifierPrefix;

+ (BOOL)isDeviceRooted;
+ (NSString *)appPlatform;

+ (NSString *)screenDPI;
+ (NSString *)screenWidth;
+ (NSString *)screenHeight;
+ (NSString *)scalefactor;

+ (NSString *)manufacturer;
+ (NSString *)model;

+ (NSString *)OSVersion;

+ (BOOL)isDeviceModelOfType:(NSString *)type;

@end
