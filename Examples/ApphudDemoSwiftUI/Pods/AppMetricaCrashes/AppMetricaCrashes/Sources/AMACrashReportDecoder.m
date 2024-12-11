
#import "AMACrashLogging.h"
#import "AMACrashReportDecoder.h"
#import "AMACrashContext.h"
#import "AMADecodedCrash.h"
#import "AMABacktraceFrame.h"
#import "AMABinaryImage.h"
#import "AMACrashLoader.h"
#import "AMAInfo.h"
#import "AMASystem.h"
#import "AMAMemory.h"
#import "AMAApplicationStatistics.h"
#import "AMACrashReportCrash.h"
#import "AMACrashReportError.h"
#import "AMAMach.h"
#import "AMASignal.h"
#import "AMANSException.h"
#import "AMACppException.h"
#import "AMAThread.h"
#import "AMABacktrace.h"
#import "AMARegister.h"
#import "AMARegistersContainer.h"
#import "AMAStack.h"
#import "AMAVersionMatcher.h"
#import "AMACrashErrorsFactory.h"
#import "AMABuildUID.h"
#import "AMAKSCrashImports.h"
#import <AppMetricaPlatform/AppMetricaPlatform.h>

NSString *const kAMASysInfoSystemName = @"systemName";
NSString *const kAMASysInfoSystemVersion = @"systemVersion";
NSString *const kAMASysInfoMachine = @"machine";
NSString *const kAMASysInfoModel = @"model";
NSString *const kAMASysInfoKernelVersion = @"kernelVersion";
NSString *const kAMASysInfoOsVersion = @"osVersion";
NSString *const kAMASysInfoIsJailbroken = @"isJailbroken";
NSString *const kAMASysInfoBootTime = @"bootTime";
NSString *const kAMASysInfoAppStartTime = @"appStartTime";
NSString *const kAMASysInfoExecutablePath = @"executablePath";
NSString *const kAMASysInfoExecutableName = @"executableName";
NSString *const kAMASysInfoBundleID = @"bundleID";
NSString *const kAMASysInfoBundleName = @"bundleName";
NSString *const kAMASysInfoBundleVersion = @"bundleVersion";
NSString *const kAMASysInfoBundleShortVersion = @"bundleShortVersion";
NSString *const kAMASysInfoAppID = @"appID";
NSString *const kAMASysInfoCpuArchitecture = @"cpuArchitecture";
NSString *const kAMASysInfoCpuType = @"cpuType";
NSString *const kAMASysInfoCpuSubType = @"cpuSubType";
NSString *const kAMASysInfoBinaryCPUType = @"binaryCPUType";
NSString *const kAMASysInfoBinaryCPUSubType = @"binaryCPUSubType";
NSString *const kAMASysInfoTimezone = @"timezone";
NSString *const kAMASysInfoProcessName = @"processName";
NSString *const kAMASysInfoProcessID = @"processID";
NSString *const kAMASysInfoParentProcessID = @"parentProcessID";
NSString *const kAMASysInfoDeviceAppHash = @"deviceAppHash";
NSString *const kAMASysInfoBuildType = @"buildType";
NSString *const kAMASysInfoStorageSize = @"storageSize";
NSString *const kAMASysInfoMemorySize = @"memorySize";
NSString *const kAMASysInfoFreeMemory = @"freeMemory";
NSString *const kAMASysInfoUsableMemory = @"usableMemory";

@interface AMACrashReportDecoder ()

@property (nonatomic, copy, readonly) id<AMADateProviding> dateProvider;

@end

@implementation AMACrashReportDecoder

#pragma mark - Public

- (instancetype)init
{
    return [self initWithCrashID:nil];
}

- (instancetype)initWithCrashID:(NSNumber *)crashID
{
    return [self initWithCrashID:crashID dateProvider:[[AMADateProvider alloc] init]];
}

- (instancetype)initWithCrashID:(NSNumber *)crashID dateProvider:(id<AMADateProviding>)dateProvider
{
    self = [super init];
    if (self) {
        _crashID = crashID;
        _dateProvider = dateProvider;
        _supportedVersionsConstaints = @[ @"3.2", @"3.3", @"3.4" ];
    }

    return self;
}

- (void)decode:(NSDictionary *)crashReport
{
    if (crashReport == nil || [crashReport[KSCrashField_Incomplete] boolValue]) {
        [self reportCorruptedCrashErrorToDelegate];
        return;
    }
    
    NSString *version = [self version:crashReport[KSCrashField_Report][KSCrashField_Version]];
    NSUInteger result = [self.supportedVersionsConstaints indexOfObjectPassingTest:
                         ^BOOL(NSString *constraint, NSUInteger idx, BOOL *stop) {
        return [AMAVersionMatcher isVersion:version matchesPessimisticConstraint:constraint];
    }];
    if (result == NSNotFound) {
        AMALogAssert(@"Unsupported version of crash report: <%@>", version);
        [self reportUnsupportedCrashVersionToDelegate:version];
        return;
    }
    
    if (crashReport[KSCrashField_RecrashReport] != nil) {
        [self reportRecrashToDelegate];
        return;
    }

    BOOL shouldReportANR = NO;
    NSDictionary *error = crashReport[KSCrashField_Crash][KSCrashField_Error];
    if ([error[KSCrashField_Type] isEqual:KSCrashExcType_User] &&
        [error[KSCrashField_UserReported][KSCrashField_Name] isEqual:kAMAApplicationNotRespondingCrashType]) {
        crashReport = [self patchANRReport:crashReport];
        shouldReportANR = YES;
    }

    AMADecodedCrash *decodedCrash = [self createDecodedCrash:crashReport];
    if (shouldReportANR) {
        [self.delegate crashReportDecoder:self didDecodeANR:decodedCrash withError:nil];
    }
    else {
        [self.delegate crashReportDecoder:self didDecodeCrash:decodedCrash withError:nil];
    }
}

- (AMASystem *)systemInfoForDictionary:(NSDictionary *)system
{
    return [self createSystem:system];
}

#pragma mark - Private

- (NSDictionary *)patchANRReport:(NSDictionary *)crashReport
{
    NSMutableArray *threads = [((NSArray *)crashReport[KSCrashField_Crash][KSCrashField_Threads]) mutableCopy];
    for (NSUInteger i = 0; i < threads.count; i++) {
        NSMutableDictionary *thread = [threads[i] mutableCopy];
        thread[KSCrashField_Crashed] = @([thread[KSCrashField_Index] longValue] == 0);
        threads[i] = [thread copy];
    }

    NSMutableDictionary *mutableCrashReport = [crashReport mutableCopy];
    NSMutableDictionary *crash = [mutableCrashReport[KSCrashField_Crash] mutableCopy];
    NSMutableDictionary *error = [crash[KSCrashField_Error] mutableCopy];

    [error removeObjectForKey:KSCrashField_UserReported];
    error[KSCrashField_Type] = KSCrashExcType_Deadlock;

    crash[KSCrashField_Error] = [error copy];
    crash[KSCrashField_Threads] = [threads copy];
    mutableCrashReport[KSCrashField_Crash] = [crash copy];

    return [mutableCrashReport copy];
}


#pragma mark - Decoded crash

- (AMADecodedCrash *)createDecodedCrash:(NSDictionary *)crashReport
{
    NSDictionary *userInfo = crashReport[KSCrashField_User];
    AMAApplicationState *appState = [self createAppState:userInfo];
    AMABuildUID *appBuildUID = [[AMABuildUID alloc] initWithString:userInfo[kAMACrashContextAppBuildUIDKey]];
    NSDictionary *errorEnvironment = userInfo[kAMACrashContextErrorEnvironmentKey];
    NSDictionary *appEnvironment = userInfo[kAMACrashContextAppEnvironmentKey];
    
    AMAInfo *info = [self createInfo:crashReport[KSCrashField_Report]];
    NSArray<AMABinaryImage *> *binaryImages = [self createBinaryImages:crashReport[KSCrashField_BinaryImages]];
    AMASystem *system = [self createSystem:crashReport[KSCrashField_System]];
    AMACrashReportCrash *crash = [self createCrash:crashReport[KSCrashField_Crash]];

    AMADecodedCrash *decodedCrash = [[AMADecodedCrash alloc] initWithAppState:appState
                                                                  appBuildUID:appBuildUID
                                                             errorEnvironment:errorEnvironment
                                                               appEnvironment:appEnvironment
                                                                         info:info
                                                                 binaryImages:binaryImages
                                                                       system:system
                                                                        crash:crash];
    return decodedCrash;
}

#pragma mark - Info

- (AMAInfo *)createInfo:(NSDictionary *)report
{
    NSString *version = [self version:report[KSCrashField_Version]];
    NSString *timestampString = report[KSCrashField_Timestamp];
    
    NSDate *timestamp = nil;
    if ([AMAVersionMatcher isVersion:version matchesPessimisticConstraint:@"3.3"]) {
        timestamp = [self dateFromMicrosecondsString:timestampString];
    }
    else {
        timestamp = [[[self class] dateFormatter] dateFromString:timestampString];
    }
    
    return [[AMAInfo alloc] initWithVersion:version
                                 identifier:report[KSCrashField_ID]
                                  timestamp:timestamp ?: [self.dateProvider currentDate]
                         virtualMachineInfo:nil];
}

- (AMAApplicationState *)createAppState:(NSDictionary *)userInfo
{
    NSString *appVersion = userInfo[kAMACrashContextAppVersionKey]; // Legacy key since 2.8.0
    NSNumber *appBuildNumber = userInfo[kAMACrashContextAppBuildNumberKey]; // Legacy key since 2.8.0
    AMAApplicationState *appState =
        [AMAApplicationState objectWithDictionaryRepresentation:userInfo[kAMACrashContextAppStateKey]];
    if (appVersion != nil || appBuildNumber != nil) {
        appState = [appState copyWithNewAppVersion:appVersion appBuildNumber:appBuildNumber.stringValue];
    }
    return [AMAApplicationStateManager stateWithFilledEmptyValues:appState];
}

#pragma mark - Binary images

- (NSArray<AMABinaryImage *> *)createBinaryImages:(NSArray *)images
{
    NSMutableArray *binaryImages = [NSMutableArray arrayWithCapacity:images.count];
    for (NSDictionary *image in images) {
        AMABinaryImage *binaryImage = [self binaryImageForKSCrashBinaryImage:image];
        if (binaryImage != nil) {
            [binaryImages addObject:binaryImage];
        }
    }

    return [binaryImages copy];
}

- (AMABinaryImage *)binaryImageForKSCrashBinaryImage:(NSDictionary *)image
{
    return [[AMABinaryImage alloc] initWithName:image[KSCrashField_Name]
                                           UUID:image[KSCrashField_UUID]
                                        address:[image[KSCrashField_ImageAddress] unsignedIntegerValue]
                                           size:[image[KSCrashField_ImageSize] unsignedIntegerValue]
                                      vmAddress:[image[KSCrashField_ImageVmAddress] unsignedIntegerValue]
                                        cpuType:[image[KSCrashField_CPUType] unsignedIntegerValue]
                                     cpuSubtype:[image[KSCrashField_CPUSubType] unsignedIntegerValue]
                                   majorVersion:[image[KSCrashField_ImageMajorVersion] intValue]
                                   minorVersion:[image[KSCrashField_ImageMinorVersion] intValue]
                                revisionVersion:[image[KSCrashField_ImageRevisionVersion] intValue]
                               crashInfoMessage:image[KSCrashField_ImageCrashInfoMessage]
                              crashInfoMessage2:image[KSCrashField_ImageCrashInfoMessage2]];
}

#pragma mark - System

- (AMASystem *)createSystem:(NSDictionary *)system
{
    return [[AMASystem alloc]
        initWithKernelVersion:system[KSCrashField_KernelVersion] ?: system[kAMASysInfoKernelVersion]
                osBuildNumber:system[KSCrashField_OSVersion] ?: system[kAMASysInfoOsVersion]
                bootTimestamp:[self timestamp:system[KSCrashField_BootTime] ?: system[kAMASysInfoBootTime]]
            appStartTimestamp:[self timestamp:system[KSCrashField_AppStartTime] ?: system[kAMASysInfoAppStartTime]]
               executablePath:system[KSCrashField_ExecutablePath] ?: system[kAMASysInfoExecutablePath]
                      cpuArch:system[KSCrashField_CPUArch] ?: system[kAMASysInfoCpuArchitecture]
                      cpuType:[system[KSCrashField_CPUType] ?: system[kAMASysInfoCpuType] intValue]
                   cpuSubtype:[system[KSCrashField_CPUSubType] ?: system[kAMASysInfoCpuSubType] intValue]
                binaryCpuType:[system[KSCrashField_BinaryCPUType] ?: system[kAMASysInfoBinaryCPUType] intValue]
             binaryCpuSubtype:[system[KSCrashField_BinaryCPUSubType] ?: system[kAMASysInfoBinaryCPUSubType] intValue]
                  processName:system[KSCrashField_ProcessName] ?: system[kAMASysInfoProcessName]
                    processId:[system[KSCrashField_ProcessID] ?: system[kAMASysInfoProcessID] longLongValue]
              parentProcessId:[system[KSCrashField_ParentProcessID] ?: system[kAMASysInfoParentProcessID] longLongValue]
                    buildType:[self buildType:system[KSCrashField_BuildType] ?: system[kAMASysInfoBuildType]]
                      storage:[system[KSCrashField_Storage] ?: system[kAMASysInfoStorageSize] longLongValue]
                       memory:[self createMemory:system[KSCrashField_Memory] ?: system]
             applicationStats:[self createApplicationStats:system[KSCrashField_AppStats]]];
}

- (AMAMemory *)createMemory:(NSDictionary *)memory
{
    return [[AMAMemory alloc]
        initWithSize:[memory[KSCrashField_Size] ?: memory[kAMASysInfoMemorySize] unsignedLongLongValue]
              usable:[memory[KSCrashField_Usable] ?: memory[kAMASysInfoUsableMemory] unsignedLongLongValue]
                free:[memory[KSCrashField_Free] ?: memory[kAMASysInfoFreeMemory] unsignedLongLongValue]];
}

- (AMAApplicationStatistics *)createApplicationStats:(NSDictionary *)appStats
{
    return [[AMAApplicationStatistics alloc]
        initWithApplicationActive:[appStats[KSCrashField_AppActive] boolValue]
          applicationInForeground:[appStats[KSCrashField_AppInFG] boolValue]
           launchesSinceLastCrash:[appStats[KSCrashField_LaunchesSinceCrash] unsignedIntValue]
           sessionsSinceLastCrash:[appStats[KSCrashField_SessionsSinceCrash] unsignedIntValue]
         activeTimeSinceLastCrash:[appStats[KSCrashField_ActiveTimeSinceCrash] doubleValue]
     backgroundTimeSinceLastCrash:[appStats[KSCrashField_BGTimeSinceCrash] doubleValue]
              sessionsSinceLaunch:[appStats[KSCrashField_SessionsSinceLaunch] unsignedIntValue]
            activeTimeSinceLaunch:[appStats[KSCrashField_ActiveTimeSinceLaunch] doubleValue]
        backgroundTimeSinceLaunch:[appStats[KSCrashField_BGTimeSinceLaunch] doubleValue]];
}

#pragma mark - Crash

- (AMACrashReportCrash *)createCrash:(NSDictionary *)crash
{
    return [[AMACrashReportCrash alloc] initWithError:[self createError:crash[KSCrashField_Error]]
                                              threads:[self createThreads:crash[KSCrashField_Threads]]];
}

- (AMACrashReportError *)createError:(NSDictionary *)error
{
    uint64_t address = [error[KSCrashField_Address] unsignedLongLongValue];
    NSString *reason = error[KSCrashField_Reason];
    AMACrashType crashType = [self crashType:error[KSCrashField_Type]];

    AMAMach *mach =
        [[AMAMach alloc] initWithExceptionType:[error[KSCrashField_Mach][KSCrashField_Exception] intValue]
                                          code:[error[KSCrashField_Mach][KSCrashField_Code] longLongValue]
                                       subcode:[error[KSCrashField_Mach][KSCrashField_Subcode] longLongValue]];
    AMASignal *signal =
        [[AMASignal alloc] initWithSignal:[error[KSCrashField_Signal][KSCrashField_Signal] intValue]
                                     code:[error[KSCrashField_Signal][KSCrashField_Code] intValue]];

    AMANSException *nsException = nil;
    if (error[KSCrashField_NSException] != nil) {
        nsException = [[AMANSException alloc] initWithName:error[KSCrashField_NSException][KSCrashField_Name]
                                                  userInfo:error[KSCrashField_NSException][KSCrashField_UserInfo]];
    }
    AMACppException *cppException = nil;
    if (error[KSCrashField_CPPException] != nil) {
        cppException = [[AMACppException alloc] initWithName:error[KSCrashField_CPPException][KSCrashField_Name]];
    }

    return [[AMACrashReportError alloc] initWithAddress:address
                                                 reason:reason
                                                   type:crashType
                                                   mach:mach
                                                 signal:signal
                                            nsexception:nsException
                                           cppException:cppException
                                         nonFatalsChain:nil
                                    virtualMachineCrash:nil];
}

#pragma mark - Threads

- (NSArray<AMAThread *> *)createThreads:(NSArray *)threads
{
    NSMutableArray<AMAThread *> *amaThreads = [NSMutableArray arrayWithCapacity:threads.count];

    for (NSDictionary *thread in threads) {
        AMAThread *amaThread =
            [[AMAThread alloc] initWithBacktrace:[self createBacktrace:thread[KSCrashField_Backtrace]]
                                       registers:[self createRegisters:thread[KSCrashField_Registers]]
                                           stack:[self createStack:thread[KSCrashField_Stack]]
                                           index:[thread[KSCrashField_Index] unsignedIntValue]
                                         crashed:[thread[KSCrashField_Crashed] boolValue]
                                      threadName:thread[KSCrashField_Name]
                                       queueName:thread[KSCrashField_DispatchQueue]];

        [amaThreads addObject:amaThread];
    }

    return [amaThreads copy];
}

- (AMABacktrace *)createBacktrace:(NSDictionary *)backtrace
{
    if (backtrace == nil) {
        return nil;
    }

    NSArray *contents = backtrace[KSCrashField_Contents];
    NSMutableArray<AMABacktraceFrame *> *frames = [NSMutableArray arrayWithCapacity:contents.count];

    for (NSDictionary *frame in contents) {
        NSNumber *lineOfCode = frame[KSCrashField_LineOfCode];
        NSNumber *instructionAddress = frame[KSCrashField_InstructionAddr];
        NSNumber *symbolAddress = frame[KSCrashField_SymbolAddr];
        NSNumber *objectAddress = frame[KSCrashField_ObjectAddr];
        NSString *symbolName = frame[KSCrashField_SymbolName];
        NSString *objectName = frame[KSCrashField_ObjectName];

        AMABacktraceFrame *backtraceFrame =
            [[AMABacktraceFrame alloc] initWithLineOfCode:lineOfCode
                                       instructionAddress:instructionAddress
                                            symbolAddress:symbolAddress
                                            objectAddress:objectAddress
                                               symbolName:symbolName
                                               objectName:objectName
                                                 stripped:[symbolAddress isEqualToNumber:objectAddress]];
        [frames addObject:backtraceFrame];
    }

    AMABacktrace *amaBacktrace = [[AMABacktrace alloc] initWithFrames:frames];
    return amaBacktrace;
}

- (AMARegistersContainer *)createRegisters:(NSDictionary *)registers
{
    if (registers == nil) {
        return nil;
    }

    AMARegistersContainer *amaRegister =
        [[AMARegistersContainer alloc] initWithBasic:[self createRegisterArray:registers[KSCrashField_Basic]]
                                           exception:[self createRegisterArray:registers[KSCrashField_Exception]]];

    return amaRegister;
}

- (NSArray<AMARegister *> *)createRegisterArray:(NSDictionary *)registers
{
    NSMutableArray *amaRegisters = [NSMutableArray arrayWithCapacity:registers.count];

    [registers enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSNumber *obj, BOOL *stop) {
        AMARegister *amaRegister = [[AMARegister alloc] initWithName:key value:[obj unsignedLongLongValue]];
        [amaRegisters addObject:amaRegister];
    }];

    return [amaRegisters copy];
}

- (AMAStack *)createStack:(NSDictionary *)stack
{
    if (stack == nil) {
        return nil;
    }

    return [[AMAStack alloc] initWithGrowDirection:[self growDirection:stack[KSCrashField_GrowDirection]]
                                         dumpStart:[stack[KSCrashField_DumpStart] unsignedLongLongValue]
                                           dumpEnd:[stack[KSCrashField_DumpEnd] unsignedLongLongValue]
                                      stackPointer:[stack[KSCrashField_StackPtr] unsignedLongLongValue]
                                          overflow:[stack[KSCrashField_Overflow] boolValue]
                                          contents:[self dataFromHexString:stack[KSCrashField_Contents]]];
}

#pragma mark - Help functions

- (NSString *)version:(id)object
{
    if ([object isKindOfClass:[NSDictionary class]]) {
        NSDictionary *veryOldVersion = (NSDictionary *)object;
        return [NSString stringWithFormat:@"%@.%@.0", veryOldVersion[@"major"], veryOldVersion[@"minor"]];
    }
    else if ([object isKindOfClass:[NSNumber class]]) {
        return [NSString stringWithFormat:@"%@.0.0", object];
    }
    else if ([object isKindOfClass:[NSString class]]) {
        return object;
    }
    return nil;
}

- (AMABuildType)buildType:(NSString *)buildType
{
    if ([buildType isEqualToString:@"simulator"]) {
        return AMABuildTypeSimulator;
    }
    else if ([buildType isEqualToString:@"debug"]) {
        return AMABuildTypeDebug;
    }
    else if ([buildType isEqualToString:@"test"]) {
        return AMABuildTypeTest;
    }
    else if ([buildType isEqualToString:@"app store"]) {
        return AMABuildTypeAppStore;
    }
    return AMABuildTypeUnknown;
}

- (AMACrashType)crashType:(NSString *)crashType
{
    if ([crashType isEqualToString:KSCrashExcType_CPPException]) {
        return AMACrashTypeCppException;
    }
    else if ([crashType isEqualToString:KSCrashExcType_Deadlock]) {
        return AMACrashTypeMainThreadDeadlock;
    }
    else if ([crashType isEqualToString:KSCrashExcType_Mach]) {
        return AMACrashTypeMachException;
    }
    else if ([crashType isEqualToString:KSCrashExcType_NSException]) {
        return AMACrashTypeNsException;
    }
    else if ([crashType isEqualToString:KSCrashExcType_Signal]) {
        return AMACrashTypeSignal;
    }
    return AMACrashTypeUserReported;
}

- (AMAGrowDirection)growDirection:(NSString *)growDirection
{
    if ([growDirection isEqualToString:@"+"]) {
        return AMAGrowDirectionPlus;
    }
    return AMAGrowDirectionMinus;
}

- (void)reportCorruptedCrashErrorToDelegate
{
    [self.delegate crashReportDecoder:self
                       didDecodeCrash:nil
                            withError:[AMACrashErrorsFactory crashReportDecodingError]];
}

- (void)reportUnsupportedCrashVersionToDelegate:(NSString *)version
{
    [self.delegate crashReportDecoder:self
                       didDecodeCrash:nil
                            withError:[AMACrashErrorsFactory crashUnsupportedReportVersionError:version]];
}

- (void)reportRecrashToDelegate
{
    [self.delegate crashReportDecoder:self
                       didDecodeCrash:nil
                            withError:[AMACrashErrorsFactory crashReportRecrashError]];
}

- (NSDate *)timestamp:(NSString *)timestamp
{
    NSDate *crashDateTime = nil;
    if (timestamp.length != 0) {
        crashDateTime = [[[self class] dateFormatter] dateFromString:timestamp];
        AMALogInfo(@"Fetched crash time from report: %@", crashDateTime);
    }
    return crashDateTime ?: [self.dateProvider currentDate];
}

- (NSData *)dataFromHexString:(NSString *)hexString
{
    const char *string = [[hexString stringByReplacingOccurrencesOfString:@" " withString:@""] UTF8String];
    NSUInteger stringLen = [hexString lengthOfBytesUsingEncoding:NSUTF8StringEncoding];

    NSMutableData *contents = [[NSMutableData alloc] init];
    unsigned char byte;
    char byteChars[3] = { '\0', '\0', '\0' };

    for (NSUInteger i = 0; i < stringLen / 2; i++) {
        byteChars[0] = string[i * 2];
        byteChars[1] = string[i * 2 + 1];
        byte = (unsigned char)strtol(byteChars, NULL, 16);
        [contents appendBytes:&byte length:1];
    }

    return [contents copy];
}

+ (NSDateFormatter *)dateFormatter
{
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        [formatter setLocale:locale];
        [formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
        [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    });
    return formatter;
}

/**
 @param string Format: `yyyy-MM-dd'T'HH:mm:ssZZZZZ`
 */
- (NSDate *)dateFromMicrosecondsString:(NSString *)string
{
    static NSString *const microsecondsPrefix = @".";
    
    NSRange microsecondsPrefixRange = [string rangeOfString:microsecondsPrefix];
    if (microsecondsPrefixRange.location == NSNotFound) { return nil; }
    NSString *microsecondsWithTimeZoneString = [string substringFromIndex:NSMaxRange(microsecondsPrefixRange)];

    NSCharacterSet *nonDigitsCharacterSet = NSCharacterSet.decimalDigitCharacterSet.invertedSet;
    NSRange timeZoneRangePrefixRange = [microsecondsWithTimeZoneString rangeOfCharacterFromSet:nonDigitsCharacterSet];
    if (timeZoneRangePrefixRange.location == NSNotFound) { return nil; }
    
    NSString *microsecondsString = [microsecondsWithTimeZoneString substringToIndex:timeZoneRangePrefixRange.location];
    if (microsecondsString == nil) { return nil; }
    double microsecondsCount = [microsecondsString doubleValue];
    
    NSString *dateStringExludingMicroseconds =
        [[string stringByReplacingOccurrencesOfString:microsecondsString withString:@""]
         stringByReplacingOccurrencesOfString:microsecondsPrefix withString:@""];
    NSDate *date = [[[self class] dateFormatter] dateFromString:dateStringExludingMicroseconds];
    NSDate *dateWithMicroseconds = [date dateByAddingTimeInterval:microsecondsCount / 1000000.0];
    
    return dateWithMicroseconds;
}

@end
