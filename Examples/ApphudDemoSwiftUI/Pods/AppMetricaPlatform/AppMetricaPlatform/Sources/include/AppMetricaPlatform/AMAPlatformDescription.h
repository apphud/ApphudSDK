
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString *const AMADeviceType NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(DeviceType);

extern AMADeviceType kAMADeviceTypeTV;
extern AMADeviceType kAMADeviceTypeTablet;
extern AMADeviceType kAMADeviceTypePhone;
extern AMADeviceType kAMADeviceTypeWatch;

typedef NS_ENUM(NSUInteger, AMAAppBuildType) {
    AMAAppBuildTypeUnknown,
    AMAAppBuildTypeDebug,
    AMAAppBuildTypeAdHoc,
    AMAAppBuildTypeTestFlight,
    AMAAppBuildTypeAppStore,
} NS_SWIFT_NAME(AppBuildType);

NS_SWIFT_NAME(PlatformDescription)
@interface AMAPlatformDescription : NSObject

// SDK //
+ (NSString *)SDKVersionName;
+ (NSUInteger)SDKBuildNumber;
+ (NSString *)SDKBuildType;
+ (NSString *)SDKBundleName;
+ (NSString *)SDKUserAgent;

// Application //
+ (NSString *)appVersion;
+ (NSString *)appVersionName;
+ (NSString *)appBuildNumber;
+ (NSString *)appID;
+ (NSString *)appIdentifierPrefix;
+ (NSString *)appPlatform;
+ (NSString *)appFramework;
+ (BOOL)appDebuggable;
+ (BOOL)isDebuggerAttached;
+ (BOOL)isExtension;
+ (AMAAppBuildType)appBuildType;

// OS //
+ (NSString *)OSName;
+ (NSString *)OSVersion;
+ (NSInteger)OSAPILevel;
+ (BOOL)isDeviceRooted;
+ (NSNumber *)bootTimestamp;

// Device //
+ (NSString *)manufacturer;
+ (NSString *)model;
+ (NSString *)screenDPI;
+ (NSString *)screenWidth;
+ (NSString *)screenHeight;
+ (NSString *)scalefactor;
+ (NSString *)deviceType;

+ (BOOL)deviceTypeIsSimulator;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
