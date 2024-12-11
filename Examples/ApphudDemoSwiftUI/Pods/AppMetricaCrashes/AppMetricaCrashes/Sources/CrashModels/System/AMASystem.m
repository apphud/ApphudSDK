
#import "AMASystem.h"

@implementation AMASystem

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
                     applicationStats:(AMAApplicationStatistics *)applicationStats
{
    self = [super init];
    if (self != nil) {
        _kernelVersion = [kernelVersion copy];
        _osBuildNumber = [osBuildNumber copy];
        _bootTimestamp = [bootTimestamp copy];
        _appStartTimestamp = [appStartTimestamp copy];
        _executablePath = [executablePath copy];
        _cpuArch = [cpuArch copy];
        _cpuType = cpuType;
        _cpuSubtype = cpuSubtype;
        _binaryCpuType = binaryCpuType;
        _binaryCpuSubtype = binaryCpuSubtype;
        _processName = [processName copy];
        _processId = processId;
        _parentProcessId = parentProcessId;
        _buildType = buildType;
        _storage = storage;
        _memory = memory;
        _applicationStats = applicationStats;
    }

    return self;
}

@end
