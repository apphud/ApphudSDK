
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

NS_SWIFT_NAME(ApplicationState)
@interface AMAApplicationState : NSObject <NSCopying, NSMutableCopying, AMADictionaryRepresentation>

@property (nonatomic, copy, readonly) NSString *appVersionName;
@property (nonatomic, assign, readonly) BOOL appDebuggable;
@property (nonatomic, copy, readonly) NSString *kitVersion;
@property (nonatomic, copy, readonly) NSString *kitVersionName;
@property (nonatomic, assign, readonly) NSUInteger kitBuildNumber;
@property (nonatomic, copy, readonly) NSString *kitBuildType;
@property (nonatomic, copy, readonly) NSString *OSVersion;
@property (nonatomic, assign, readonly) NSInteger OSAPILevel;
@property (nonatomic, copy, readonly) NSString *locale;
@property (nonatomic, assign, readonly) BOOL isRooted;
@property (nonatomic, copy, readonly) NSString *UUID;
@property (nonatomic, copy, readonly) NSString *deviceID;
@property (nonatomic, copy, readonly) NSString *IFV;
@property (nonatomic, copy, readonly) NSString *IFA;
@property (nonatomic, assign, readonly) BOOL LAT;
@property (nonatomic, copy, readonly) NSString *appBuildNumber;

- (instancetype)initWithAppVersionName:(NSString *)appVersionName
                         appDebuggable:(BOOL)appDebuggable
                            kitVersion:(NSString *)kitVersion
                        kitVersionName:(NSString *)kitVersionName
                        kitBuildNumber:(NSUInteger)kitBuildNumber
                          kitBuildType:(NSString *)kitBuildType
                             OSVersion:(NSString *)OSVersion
                            OSAPILevel:(NSInteger)OSAPILevel
                                locale:(NSString *)locale
                              isRooted:(BOOL)isRooted
                                  UUID:(NSString *)UUID
                              deviceID:(NSString *)deviceID
                                   IFV:(NSString *)IFV
                                   IFA:(NSString *)IFA
                                   LAT:(BOOL)LAT
                        appBuildNumber:(NSString *)appBuildNumber;

- (instancetype)copyWithNewAppVersion:(NSString *)appVersion appBuildNumber:(NSString *)appBuildNumber;

@end

NS_SWIFT_NAME(MutableApplicationState)
@interface AMAMutableApplicationState : AMAApplicationState

@property (nonatomic, copy, readwrite) NSString *appVersionName;
@property (nonatomic, assign, readwrite) BOOL appDebuggable;
@property (nonatomic, copy, readwrite) NSString *kitVersion;
@property (nonatomic, copy, readwrite) NSString *kitVersionName;
@property (nonatomic, assign, readwrite) NSUInteger kitBuildNumber;
@property (nonatomic, copy, readwrite) NSString *kitBuildType;
@property (nonatomic, copy, readwrite) NSString *OSVersion;
@property (nonatomic, assign, readwrite) NSInteger OSAPILevel;
@property (nonatomic, copy, readwrite) NSString *locale;
@property (nonatomic, assign, readwrite) BOOL isRooted;
@property (nonatomic, copy, readwrite) NSString *UUID;
@property (nonatomic, copy, readwrite) NSString *deviceID;
@property (nonatomic, copy, readwrite) NSString *IFV;
@property (nonatomic, copy, readwrite) NSString *IFA;
@property (nonatomic, assign, readwrite) BOOL LAT;
@property (nonatomic, copy, readwrite) NSString *appBuildNumber;

@end
