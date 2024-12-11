
#import <Foundation/Foundation.h>

@class AMABuildUID;
@class AMAApplicationState;
@class AMAInfo;
@class AMABinaryImage;
@class AMASystem;
@class AMACrashReportCrash;
@class AMABacktrace;

@interface AMADecodedCrash : NSObject <NSCopying>

@property (nonatomic, copy, readonly) AMAApplicationState *appState;
@property (nonatomic, copy, readonly) AMABuildUID *appBuildUID;
@property (nonatomic, copy, readonly) NSDictionary *errorEnvironment;
@property (nonatomic, copy, readonly) NSDictionary *appEnvironment;
@property (nonatomic, copy, readonly) AMABacktrace *crashedThreadBacktrace;

@property (nonatomic, strong, readonly) AMAInfo *info;
@property (nonatomic, copy, readonly) NSArray<AMABinaryImage *> *binaryImages;
@property (nonatomic, strong, readonly) AMASystem *system;
@property (nonatomic, strong, readonly) AMACrashReportCrash *crash;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithAppState:(AMAApplicationState *)appState
                     appBuildUID:(AMABuildUID *)appBuildUID
                errorEnvironment:(NSDictionary *)errorEnvironment
                  appEnvironment:(NSDictionary *)appEnvironment
                            info:(AMAInfo *)info
                    binaryImages:(NSArray<AMABinaryImage *> *)binaryImages
                          system:(AMASystem *)system
                           crash:(AMACrashReportCrash *)crash;

+ (instancetype)crashWithAppState:(AMAApplicationState *)appState
                      appBuildUID:(AMABuildUID *)appBuildUID
                 errorEnvironment:(NSDictionary *)errorEnvironment
                   appEnvironment:(NSDictionary *)appEnvironment
                             info:(AMAInfo *)info
                     binaryImages:(NSArray<AMABinaryImage *> *)binaryImages
                           system:(AMASystem *)system
                            crash:(AMACrashReportCrash *)crash;

@end
