
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#include <objc/runtime.h>
#import <Security/Security.h>
#import "AMADeviceDescription.h"
#import "AMAAppIdentifierProvider.h"
#import "AMAJailbreakCheck.h"

@implementation AMADeviceDescription

#pragma mark - Public

#pragma mark - Application Identifier Prefix

+ (NSString *)appIdentifierPrefix
{
    static NSString *appIdentifierPrefix = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        appIdentifierPrefix = [AMAAppIdentifierProvider appIdentifierPrefix];
    });
    return appIdentifierPrefix;
    
}

+ (NSString *)oldAppIdentifierPrefix
{
    static NSString *appIdentifierPrefix = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        appIdentifierPrefix = [AMAAppIdentifierProvider appIdentifierPrefix];
    });
    return appIdentifierPrefix;
    
}

#pragma mark - Device type

+ (BOOL)isDeviceRooted
{
    static BOOL isRooted = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        isRooted = (AMAJailbreakCheck.jailbroken == AMA_KFJailbroken);
    });
    return isRooted;
}

+ (NSString *)appPlatform
{
    switch ([[UIDevice currentDevice] userInterfaceIdiom]) {
        case UIUserInterfaceIdiomPad:
            return @"ipad";
        default:
            return @"iphone";
    }
}

#pragma mark - Screen

+ (NSString *)screenDPI
{
#if TARGET_OS_TV
    return nil;
#else
    NSString *model = [self model];
    
    NSDictionary<NSString *, NSNumber *> *dpiValues = [[self class] dpiValues];
    
    NSUInteger dpi = 326;
    
    NSNumber *value = [dpiValues valueForKey:model];
    if (value != nil) {
        dpi = value.unsignedIntegerValue;
    }
    
    NSString *result = [NSString stringWithFormat:@"%d", (int)dpi];
    return result;
#endif
}

+ (NSString *)screenWidth
{
    CGRect bounds = [[UIScreen mainScreen] bounds];
    CGFloat width = CGRectGetWidth(bounds);
    NSString *result = [NSString stringWithFormat:@"%.0f", width];
    return result;
}

+ (NSString *)screenHeight
{
    CGRect bounds = [[UIScreen mainScreen] bounds];
    CGFloat height = CGRectGetHeight(bounds);
    NSString *result = [NSString stringWithFormat:@"%.0f", height];
    return result;
}

+ (NSString *)scalefactor
{
    CGFloat scale = [self screenScale];
    NSString *result = [NSString stringWithFormat:@"%0.2f", scale];
    return result;
}

#pragma mark - hardware

+ (NSString *)manufacturer
{
    return @"Apple";
}

+ (NSString *)model
{
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *model = [NSString stringWithCString:systemInfo.machine
                                         encoding:NSUTF8StringEncoding];
    return model;
}

#pragma mark - OS

+ (NSString *)OSVersion
{
    NSString *systemVersion = [[UIDevice currentDevice] systemVersion];
    return systemVersion;
}

+ (BOOL)isDeviceModelOfType:(NSString *)type
{
    NSString *model = [[[UIDevice currentDevice] model] lowercaseString];
    return ([model rangeOfString:[type lowercaseString]].location != NSNotFound);
}

#pragma mark - Private

//FIXME: mainScreen deprecated
+ (CGFloat)screenScale
{
    CGFloat screenScale = 1.0f;
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
        screenScale = [[UIScreen mainScreen] scale];
    }
    return screenScale;
}

+ (NSDictionary<NSString *, NSNumber *> *)dpiValues
{
    return @{ @"iPhone14,4" : @476, // iPhone 13 mini
              @"iPhone13,1" : @476, // iPhone 12 mini
              
              @"iPhone14,7" : @460, // iPhone 14
              @"iPhone15,2" : @460, // iPhone 14 Pro
              @"iPhone15,3" : @460, // iPhone 14 Pro Max
              @"iPhone14,5" : @460, // iPhone 13
              @"iPhone14,2" : @460, // iPhone 13 Pro
              @"iPhone13,2" : @460, // iPhone 12
              @"iPhone13,3" : @460, // iPhone 12 Pro
              
              @"iPhone14,8" : @458, // iPhone 14 Plus
              @"iPhone14,3" : @458, // iPhone 13 Pro Max
              @"iPhone13,4" : @458, // iPhone 12 Pro Max
              @"iPhone12,3" : @458, // iPhone 11 Pro
              @"iPhone12,5" : @458, // iPhone 11 Pro Max
              @"iPhone11,2" : @458, // iPhone XS
              @"iPhone11,4" : @458, // iPhone XS Max
              @"iPhone11,6" : @458, // iPhone XS Max
              @"iPhone10,3" : @458, // iPhone X
              @"iPhone10,6" : @458, // iPhone X
              
              @"iPhone10,2" : @401, // iPhone 8 Plus
              @"iPhone10,5" : @401, // iPhone 8 Plus
              @"iPhone9,2" : @401, // iPhone 7 Plus
              @"iPhone9,4" : @401, // iPhone 7 Plus
              @"iPhone8,2" : @401, // iPhone 6S Plus
              @"iPhone7,1" : @401, // iPhone 6 Plus
              
              @"iPhone12,1" : @326, // iPhone 11
              @"iPhone11,8" : @326, // iPhone XR
              @"iPhone14,6" : @326, // iPhone SE (3rd generation)
              @"iPhone12,8" : @326, // iPhone SE (2nd generation)
              @"iPhone10,1" : @326, // iPhone 8
              @"iPhone10,4" : @326, // iPhone 8
              @"iPhone9,1" : @326, // iPhone 7
              @"iPhone9,3" : @326, // iPhone 7
              @"iPhone8,1" : @326, // iPhone 6S
              @"iPhone7,2" : @326, // iPhone 6
              @"iPhone8,4" : @326, // iPhone SE
              @"iPhone6,1" : @326, // iPhone 5S
              @"iPhone6,2" : @326, // iPhone 5S
              @"iPhone5,3" : @326, // iPhone 5C
              @"iPhone5,4" : @326, // iPhone 5C
              @"iPhone5,1" : @326, // iPhone 5
              @"iPhone5,2" : @326, // iPhone 5
              @"iPod9,1" : @326, // iPod touch (7th generation)
              @"iPod7,1" : @326, // iPod touch (6th generation)
              @"iPod5,1" : @326, // iPod touch (5th generation)
              @"iPhone4,1" : @326, // iPhone 4S
              @"iPad14,1" : @326, // iPad mini (6th generation)
              @"iPad14,2" : @326, // iPad mini (6th generation)
              @"iPad11,1" : @326, // iPad mini (5th generation)
              @"iPad11,2" : @326, // iPad mini (5th generation)
              @"iPad5,1" : @326, // iPad mini 4
              @"iPad5,2" : @326, // iPad mini 4
              @"iPad4,7" : @326, // iPad mini 3
              @"iPad4,8" : @326, // iPad mini 3
              @"iPad4,9" : @326, // iPad mini 3
              @"iPad4,4" : @326, // iPad mini 2
              @"iPad4,5" : @326, // iPad mini 2
              @"iPad4,6" : @326, // iPad mini 2
              
              @"iPad13,18" : @264, // iPad (10th generation)
              @"iPad13,19" : @264, // iPad (10th generation)
              @"iPad14,3" : @264, // iPad Pro (11″, 4th generation)
              @"iPad14,4" : @264, // iPad Pro (11″, 4th generation)
              @"iPad14,3-A" : @264, // iPad Pro (11″, 4th generation)
              @"iPad14,3-B" : @264, // iPad Pro (11″, 4th generation)
              @"iPad14,4-A" : @264, // iPad Pro (11″, 4th generation)
              @"iPad14,4-B" : @264, // iPad Pro (11″, 4th generation)
              @"iPad14,5" : @264, // iPad Pro (12.9″, 6th generation)
              @"iPad14,6" : @264, // iPad Pro (12.9″, 6th generation)
              @"iPad14,5-A" : @264, // iPad Pro (12.9″, 6th generation)
              @"iPad14,5-B" : @264, // iPad Pro (12.9″, 6th generation)
              @"iPad14,6-A" : @264, // iPad Pro (12.9″, 6th generation)
              @"iPad14,6-B" : @264, // iPad Pro (12.9″, 6th generation)
              @"iPad13,16" : @264, // iPad Air (5th generation)
              @"iPad13,17" : @264, // iPad Air (5th generation)
              @"iPad12,1" : @264, // iPad (9th generation)
              @"iPad12,2" : @264, // iPad (9th generation)
              @"iPad13,8" : @264, // iPad Pro (12.9″, 5th generation)
              @"iPad13,9" : @264, // iPad Pro (12.9″, 5th generation)
              @"iPad13,10" : @264, // iPad Pro (12.9″, 5th generation)
              @"iPad13,11" : @264, // iPad Pro (12.9″, 5th generation)
              @"iPad13,4" : @264, // iPad Pro (11″, 3rd generation)
              @"iPad13,5" : @264, // iPad Pro (11″, 3rd generation)
              @"iPad13,6" : @264, // iPad Pro (11″, 3rd generation)
              @"iPad13,7" : @264, // iPad Pro (11″, 3rd generation)
              @"iPad13,1" : @264, // iPad Air (4th generation)
              @"iPad13,2" : @264, // iPad Air (4th generation)
              @"iPad11,6" : @264, // iPad (8th generation)
              @"iPad11,7" : @264, // iPad (8th generation)
              @"iPad8,11" : @264, // iPad Pro (12.9″, 4th generation)
              @"iPad8,12" : @264, // iPad Pro (12.9″, 4th generation)
              @"iPad8,9" : @264, // iPad Pro (11″, 2nd generation)
              @"iPad8,10" : @264, // iPad Pro (11″, 2nd generation)
              @"iPad7,11" : @264, // iPad (7th generation)
              @"iPad7,12" : @264, // iPad (7th generation)
              @"iPad11,3" : @264, // iPad Air (3rd generation)
              @"iPad11,4" : @264, // iPad Air (3rd generation)
              @"iPad8,5" : @264, // iPad Pro (12.9″, 3rd generation)
              @"iPad8,6" : @264, // iPad Pro (12.9″, 3rd generation)
              @"iPad8,7" : @264, // iPad Pro (12.9″, 3rd generation)
              @"iPad8,8" : @264, // iPad Pro (12.9″, 3rd generation)
              @"iPad8,1" : @264, // iPad Pro (11″)
              @"iPad8,2" : @264, // iPad Pro (11″)
              @"iPad8,3" : @264, // iPad Pro (11″)
              @"iPad8,4" : @264, // iPad Pro (11″)
              @"iPad7,5" : @264, // iPad (6th generation)
              @"iPad7,6" : @264, // iPad (6th generation)
              @"iPad7,3" : @264, // iPad Pro (10.5″)
              @"iPad7,4" : @264, // iPad Pro (10.5″)
              @"iPad7,1" : @264, // iPad Pro (12.9″, 2nd generation)
              @"iPad7,2" : @264, // iPad Pro (12.9″, 2nd generation)
              @"iPad6,11" : @264, // iPad (5th generation)
              @"iPad6,12" : @264, // iPad (5th generation)
              @"iPad6,7" : @264, // iPad Pro (12.9″)
              @"iPad6,8" : @264, // iPad Pro (12.9″)
              @"iPad6,3" : @264, // iPad Pro (9.7″)
              @"iPad6,4" : @264, // iPad Pro (9.7″)
              @"iPad5,3" : @264, // iPad Air 2
              @"iPad5,4" : @264, // iPad Air 2
              @"iPad4,1" : @264, // iPad Air
              @"iPad4,2" : @264, // iPad Air
              @"iPad4,3" : @264, // iPad Air
              @"iPad3,4" : @264, // iPad (4th generation)
              @"iPad3,5" : @264, // iPad (4th generation)
              @"iPad3,6" : @264, // iPad (4th generation)
              @"iPad3,1" : @264, // iPad (3rd generation)
              @"iPad3,2" : @264, // iPad (3rd generation)
              @"iPad3,3" : @264, // iPad (3rd generation)
              
              @"iPad2,5" : @163, // iPad mini
              @"iPad2,6" : @163, // iPad mini
              @"iPad2,7" : @163, // iPad mini
              
              @"iPad2,1" : @132, // iPad 2
              @"iPad2,2" : @132, // iPad 2
              @"iPad2,3" : @132, // iPad 2
              @"iPad2,4" : @132, // iPad 2
    };
}

@end
