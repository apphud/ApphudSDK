
#import <Foundation/Foundation.h>

@class AMAMemory;
@class AMAApplicationStatistics;

typedef NS_ENUM(NSInteger, AMABuildType) {
    AMABuildTypeUnknown,
    AMABuildTypeSimulator,
    AMABuildTypeDebug,
    AMABuildTypeTest,
    AMABuildTypeAppStore,
};

@interface AMASystem : NSObject

@property (nonatomic, copy, readonly) NSString *kernelVersion;
@property (nonatomic, copy, readonly) NSString *osBuildNumber;
@property (nonatomic, copy, readonly) NSDate *bootTimestamp;
@property (nonatomic, copy, readonly) NSDate *appStartTimestamp;
@property (nonatomic, copy, readonly) NSString *executablePath;
@property (nonatomic, copy, readonly) NSString *cpuArch;
@property (nonatomic, assign, readonly) int32_t cpuType;
@property (nonatomic, assign, readonly) int32_t cpuSubtype;
@property (nonatomic, assign, readonly) int32_t binaryCpuType;
@property (nonatomic, assign, readonly) int32_t binaryCpuSubtype;
@property (nonatomic, copy, readonly) NSString *processName;
@property (nonatomic, assign, readonly) int64_t processId;
@property (nonatomic, assign, readonly) int64_t parentProcessId;
@property (nonatomic, assign, readonly) AMABuildType buildType;
@property (nonatomic, assign, readonly) int64_t storage;
@property (nonatomic, strong, readonly) AMAMemory *memory;
@property (nonatomic, strong, readonly) AMAApplicationStatistics *applicationStats;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithKernelVersion:(NSString *)kernelVersion
                        osBuildNumber:(NSString *)osBuildNumber
                        bootTimestamp:(NSDate *)bootTimestamp
                    appStartTimestamp:(NSDate *)appStartTimestamp
                       executablePath:(NSString *)executablePath
                              cpuArch:(NSString *)cpuArch
                              cpuType:(int32_t)cpuType
                           cpuSubtype:(int32_t)cpuSubtype
                        binaryCpuType:(int32_t)binaryCpuType
                     binaryCpuSubtype:(int32_t)binaryCpuSubtype
                          processName:(NSString *)processName
                            processId:(int64_t)processId
                      parentProcessId:(int64_t)parentProcessId
                            buildType:(AMABuildType)buildType
                              storage:(int64_t)storage
                               memory:(AMAMemory *)memory
                     applicationStats:(AMAApplicationStatistics *)applicationStats;


@end
