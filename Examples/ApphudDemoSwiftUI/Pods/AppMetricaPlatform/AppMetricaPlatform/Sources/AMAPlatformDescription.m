
#import <AppMetricaPlatform/AppMetricaPlatform.h>
#import "AMAPlatformCore.h"
#include <sys/sysctl.h>
#import "AMAAppVersionProvider.h"
#import "AMADeviceDescription.h"
#import "AMAEntitlementsExtractor.h"

static NSString *const kAMANativeAppFramework = @"native";
static NSString *const kAMAUnityAppFramework = @"unity";
static NSString *const kAMAXamarinAppFramework = @"xamarin";
static NSString *const kAMAReactAppFramework = @"react";
static NSString *const kAMACordovaAppFramework = @"cordova";
static NSString *const kAMAFlutterAppFramework = @"flutter";

NSString *const kAMADeviceTypeTV = @"tv";
NSString *const kAMADeviceTypeTablet = @"tablet";
NSString *const kAMADeviceTypePhone = @"phone";
NSString *const kAMADeviceTypeWatch = @"watch";

#ifndef AMA_BUILD_TYPE
    #define AMA_BUILD_TYPE "undefined"
#endif

@implementation AMAPlatformDescription

#pragma mark - SDK

+ (NSString *)SDKVersionName
{
#ifdef AMA_VERSION_PRERELEASE_ID
    return [NSString stringWithFormat:@"%d.%d.%d-%s",
            AMA_VERSION_MAJOR, AMA_VERSION_MINOR, AMA_VERSION_PATCH, AMA_VERSION_PRERELEASE_ID];
#else
    return [NSString stringWithFormat:@"%d.%d.%d", AMA_VERSION_MAJOR, AMA_VERSION_MINOR, AMA_VERSION_PATCH];
#endif
}

+ (NSUInteger)SDKBuildNumber
{
    return AMA_BUILD_NUMBER;
}

+ (NSString *)SDKBuildType
{
    return @AMA_BUILD_TYPE;
}

+ (NSString *)SDKBundleName
{
    return @"io.appmetrica";
}

+ (NSString *)SDKUserAgent
{
    NSString *SDKName = @"io.appmetrica.analytics";
    NSString *versionName = [self SDKVersionName];
    NSUInteger buildNumber = [self SDKBuildNumber];
    return [[self class] userAgentWithName:SDKName
                                   version:versionName
                               buildNumber:buildNumber];
}

#pragma mark - Application

+ (NSString *)appVersion
{
    return [[[self class] appVersionProvider] appVersion];
}

+ (NSString *)appVersionName
{
    return [[[self class] appVersionProvider] appVersionName];
}

+ (NSString *)appBuildNumber
{
    return [[[self class] appVersionProvider] appBuildNumber];
}

+ (NSString *)appID
{
    return [[[self class] appVersionProvider] appID];
}

+ (NSString *)appIdentifierPrefix
{
    return [AMADeviceDescription appIdentifierPrefix];
}

+ (NSString *)appPlatform
{
    return [AMADeviceDescription appPlatform];
}

+ (NSString *)appFramework
{
    NSDictionary *frameworks = @{
            @"UnityAppController" : kAMAUnityAppFramework,
            @"XamarinAssociatedObject" : kAMAXamarinAppFramework,
            @"XamarinGCSupport" : kAMAXamarinAppFramework,
            @"XamarinNSThreadObject" : kAMAXamarinAppFramework,
            @"RCTRootView" : kAMAReactAppFramework,
            @"CDVPlugin" : kAMACordovaAppFramework,
            @"FlutterEngine" : kAMAFlutterAppFramework
    };

    for (NSString *stringClass in frameworks) {
        Class frameworkClass = NSClassFromString(stringClass);
        if (frameworkClass != Nil) {
            return frameworks[stringClass];
        }
    }

    return kAMANativeAppFramework;
}

+ (BOOL)appDebuggable
{
    return [self appBuildType] == AMAAppBuildTypeDebug;
}

+ (BOOL)isDebuggerAttached
{
    BOOL debuggerIsAttached = NO;

    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    int name[] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};

    if (sysctl(name, sizeof(name)/sizeof(*name), &info, &info_size, NULL, 0) != -1) {
        debuggerIsAttached = (info.kp_proc.p_flag & P_TRACED) != 0;
    }
    return debuggerIsAttached;
}

+ (BOOL)isExtension
{
    return [[NSBundle mainBundle].executablePath rangeOfString:@".appex"].location != NSNotFound;
}

+ (AMAAppBuildType)appBuildType
{
    static AMAAppBuildType appBuildType = AMAAppBuildTypeUnknown;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        appBuildType = [self currentAppBuildType];
    });
    return appBuildType;
}

#pragma mark - OS

+ (NSString *)OSName
{
    // We use iOS OS name for all platforms (iOS, watchOs, tvOS)
    return @"iOS";
}

+ (NSString *)OSVersion
{
    return [AMADeviceDescription OSVersion];
}

+ (NSInteger)OSAPILevel
{
    NSString *OSAPILevel = [[[self class] OSVersion] componentsSeparatedByString:@"."].firstObject;
    NSInteger levelNumber = [OSAPILevel integerValue];
    return levelNumber;
}

+ (BOOL)isDeviceRooted
{
    return [AMADeviceDescription isDeviceRooted];
}

+ (NSNumber *)bootTimestamp
{
    NSNumber *bootTimestamp = nil;
    struct timeval bootTimeValue = {0};
    size_t size = sizeof(bootTimeValue);
    if (sysctlbyname("kern.boottime", &bootTimeValue, &size, NULL, 0) == 0) {
        bootTimestamp = @(bootTimeValue.tv_sec);
    }
    else {
        AMALogWarn(@"Failed to get boot time with error: %s", strerror(errno));
    }
    return bootTimestamp;
}

#pragma mark - Device

+ (NSString *)manufacturer
{
    return [AMADeviceDescription manufacturer];
}

+ (NSString *)model
{
    return [AMADeviceDescription model];
}

+ (NSString *)screenDPI
{
    return [AMADeviceDescription screenDPI];
}

+ (NSString *)screenWidth
{
    return [AMADeviceDescription screenWidth];
}

+ (NSString *)screenHeight
{
    return [AMADeviceDescription screenHeight];
}

+ (NSString *)scalefactor
{
    return [AMADeviceDescription scalefactor];
}

+ (NSString *)deviceType
{
#if TARGET_OS_TV
    return kAMADeviceTypeTV;
#elif TARGET_OS_WATCH
    return kAMADeviceTypeWatch;
#else
    return [AMADeviceDescription isDeviceModelOfType:@"ipad"] ? kAMADeviceTypeTablet : kAMADeviceTypePhone;
#endif
}

+ (BOOL)deviceTypeIsSimulator
{
    return [AMADeviceDescription isDeviceModelOfType:@"simulator"] ||
           [NSProcessInfo processInfo].environment[@"SIMULATOR_DEVICE_NAME"] != nil;
}

#pragma mark - AppVersionProvider

+ (AMAAppVersionProvider *)appVersionProvider
{
    static AMAAppVersionProvider *appVersionProvider = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        appVersionProvider = [[AMAAppVersionProvider alloc] init];
    });
    return appVersionProvider;
}

#pragma mark - Private

+ (NSDictionary *)embeddedMobileProvisioning
{
    NSDictionary *embeddedMobileProvisioning = nil;

    NSString *provisionPath = [[NSBundle mainBundle] pathForResource:@"embedded" ofType:@"mobileprovision"];
    NSData *profileData = nil;
    if (provisionPath != nil) {
        profileData = [NSData dataWithContentsOfFile:provisionPath options:0 error:NULL];
    }

    NSRange plistRange = [self rangeOfDataStartingWithUTFString:"<?xml version="
                                                   endUTFString:"</plist>"
                                                         inData:profileData];
    if (plistRange.location != NSNotFound) {
        NSData *plistData = [profileData subdataWithRange:plistRange];

        NSError *error = nil;
        NSPropertyListFormat format;
        embeddedMobileProvisioning = [NSPropertyListSerialization propertyListWithData:plistData
                                                                               options:NSPropertyListImmutable
                                                                                format:&format
                                                                                 error:&error];
        if (error != nil) {
            AMALogError(@"Parsing provisioning plist failed: %@", error);
        }
        if ([embeddedMobileProvisioning isKindOfClass:[NSDictionary class]] == NO) {
            embeddedMobileProvisioning = nil;
        }
    }

    return embeddedMobileProvisioning;
}

+ (AMAAppBuildType)currentAppBuildType
{
    AMAAppBuildType appBuildType = AMAAppBuildTypeUnknown;

    NSString *receiptPath = [self receiptPath];
    if ([self isAppStoreReceiptPath:receiptPath]) {
        appBuildType = AMAAppBuildTypeAppStore;
    }
    else if ([self isDebuggerAttached]) {
        appBuildType = AMAAppBuildTypeDebug;
    }
    else {
        NSDictionary *profile = [self embeddedMobileProvisioning];
        if (profile != nil) {
            if ([self getTaskAllowFieldForProfile:profile].boolValue) {
                appBuildType = AMAAppBuildTypeDebug;
            }
            else {
                appBuildType = AMAAppBuildTypeAdHoc;
            }
        }
        else if ([self isTestFlightReceiptPath:receiptPath]) {
            appBuildType = AMAAppBuildTypeTestFlight;
        }
    }

    return appBuildType;
}

+ (NSDictionary *)entitlements
{
    static dispatch_once_t onceToken;
    static NSDictionary *entitlements = nil;
    
    dispatch_once(&onceToken, ^{
        entitlements = [AMAEntitlementsExtractor entitlements];
    });
    
    return entitlements;
}

+ (NSString *)receiptPath
{
    return [NSBundle mainBundle].appStoreReceiptURL.path;
}

+ (BOOL)isAppStoreReceiptPath:(NSString *)receiptPath
{
    BOOL isAppStoreReceiptPath = [receiptPath.lastPathComponent isEqualToString:@"receipt"];
    isAppStoreReceiptPath = isAppStoreReceiptPath && [[NSFileManager defaultManager] fileExistsAtPath:receiptPath];
    return isAppStoreReceiptPath;
}

+ (BOOL)isTestFlightReceiptPath:(NSString *)receiptPath
{
    BOOL isTestFlightReceiptPath = [receiptPath.lastPathComponent isEqualToString:@"sandboxReceipt"];
    return isTestFlightReceiptPath;
}

+ (NSRange)rangeOfDataStartingWithUTFString:(nonnull const char *)startString
                               endUTFString:(nonnull const char *)endString
                                     inData:(NSData *)data
{
    NSRange range = NSMakeRange(NSNotFound, 0);
    NSUInteger startStringLength = strlen(startString);
    NSUInteger endStringLength = strlen(endString);
    if (data.length >= startStringLength + endStringLength) {
        NSRange startRange = [data rangeOfData:[NSData dataWithBytes:startString length:startStringLength]
                                       options:0
                                         range:NSMakeRange(0, data.length)];
        if (startRange.location != NSNotFound) {
            NSRange endRange = [data rangeOfData:[NSData dataWithBytes:endString length:endStringLength]
                                         options:0
                                           range:NSMakeRange(startRange.location, data.length - startRange.location)];
            if (endRange.location != NSNotFound) {
                range = NSMakeRange(startRange.location, endRange.location - startRange.location + endRange.length);
            }
        }
    }
    return range;
}

+ (NSNumber *)getTaskAllowFieldForProfile:(NSDictionary *)profile
{
    NSNumber *result = nil;
    NSDictionary *entitlements = profile[@"Entitlements"];
    if ([entitlements isKindOfClass:[NSDictionary class]]) {
        NSNumber *getAllowTaskField = entitlements[@"get-task-allow"];
        if ([getAllowTaskField isKindOfClass:[NSNumber class]]) {
            result = getAllowTaskField;
        }
    }
    return result;
}

+ (NSString *)userAgentWithName:(NSString *)name
                        version:(NSString *)version
                    buildNumber:(NSUInteger)build
{
    NSString *format = @"%@/%@.%lu (%@ %@; %@ %@)";
    NSString *manufacturer = [self manufacturer];
    NSString *model = [self model];
    NSString *OSName = [self OSName];
    NSString *OSVersion = [self OSVersion];
    return [NSString stringWithFormat:format, name, version, build, manufacturer, model, OSName, OSVersion];
}

@end
