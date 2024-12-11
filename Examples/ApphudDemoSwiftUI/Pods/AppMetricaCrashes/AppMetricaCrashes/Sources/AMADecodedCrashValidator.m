
#import "AMADecodedCrashValidator.h"
#import "AMAInfo.h"
#import "AMABinaryImage.h"
#import "AMASystem.h"
#import "AMACrashReportCrash.h"
#import "AMARegister.h"
#import "AMACrashReportError.h"
#import "AMADecodedCrash.h"
#import "AMAMemory.h"
#import "AMAApplicationStatistics.h"
#import "AMABacktraceFrame.h"

NSString *const kAMADecodedCrashValidatorErrorDomain = @"io.appmetrica.AMADecodedCrashValidator";

NSString *const kAMAValidatorUserInfoCriticalErrorsKey = @"Critical errors";
NSString *const kAMAValidatorUserInfoSuspiciousErrorsKey = @"Suspicious errors";
NSString *const kAMAValidatorUserInfoNonCriticalErrorsKey = @"Non-critical errors";

static NSString *const kAMAUserInfoRequired = @"required";
static NSString *const kAMAUserInfoInvalid = @"invalid";
static NSString *const kAMAUserInfoEmpty = @"empty";

@interface AMADecodedCrashValidator ()

@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray *> *criticalErrors;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray *> *suspiciousErrors;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray *> *nonCriticalErrors;

@property (nonatomic, assign) AMACrashValidatorErrorCode highestError;

@end

@implementation AMADecodedCrashValidator

#pragma mark - Public

- (instancetype)init
{
    self = [super init];

    if (self != nil) {
        [self reset];
    }

    return self;
}

- (NSError *)result
{
    if (self.highestError != AMACrashValidatorErrorCodeNone) {
        NSDictionary *userInfo = @{
            kAMAValidatorUserInfoCriticalErrorsKey : [self.criticalErrors copy],
            kAMAValidatorUserInfoSuspiciousErrorsKey : [self.suspiciousErrors copy],
            kAMAValidatorUserInfoNonCriticalErrorsKey : [self.nonCriticalErrors copy],
        };
        return [NSError errorWithDomain:kAMADecodedCrashValidatorErrorDomain
                                   code:self.highestError
                               userInfo:userInfo];
    }
    return nil;
}

- (void)reset
{
    _highestError = AMACrashValidatorErrorCodeNone;
    _criticalErrors = [NSMutableDictionary dictionary];
    _suspiciousErrors = [NSMutableDictionary dictionary];
    _nonCriticalErrors = [NSMutableDictionary dictionary];
}

#pragma mark Validation

- (BOOL)validateDecodedCrash:(AMADecodedCrash *)crash
{
    BOOL errorFound = NO;

    if (crash.info == nil) {
        errorFound = YES;
        [self addErrorPath:@"Crash.info" toCriticalErrorsForKey:kAMAUserInfoRequired];
    }
    if (crash.crash == nil) {
        errorFound = YES;
        [self addErrorPath:@"Crash.crash" toCriticalErrorsForKey:kAMAUserInfoRequired];
    }
    if (crash.binaryImages.count == 0) {
        [self addErrorPath:@"Crash.binary_images" toSuspiciousErrorsForKey:kAMAUserInfoEmpty];
    }

    return errorFound;
}

- (BOOL)validateInfo:(AMAInfo *)info
{
    BOOL errorFound = NO;

    if (info.identifier == nil) {
        errorFound = YES;
        [self addErrorPath:@"Crash.info.id" toCriticalErrorsForKey:kAMAUserInfoRequired];
    }
    if (info.timestamp == nil) {
        errorFound = YES;
        [self addErrorPath:@"Crash.info.timestamp" toCriticalErrorsForKey:kAMAUserInfoRequired];
    }

    return errorFound;
}

- (BOOL)validateBinaryImage:(AMABinaryImage *)image
{
    BOOL errorFound = NO;

    if (image.name == nil) {
        errorFound = YES;
        [self addErrorPath:@"Crash.BinaryImage.name" toNonCriticalErrorsForKey:kAMAUserInfoRequired];
    }
    if (image.UUID == nil) {
        errorFound = YES;
        [self addErrorPath:@"Crash.BinaryImage.uuid" toNonCriticalErrorsForKey:kAMAUserInfoRequired];
    }

    if (image.address == 0) {
        [self addErrorPath:@"Crash.BinaryImage.address" toSuspiciousErrorsForKey:kAMAUserInfoInvalid];
    }
    if (image.size == 0) {
        [self addErrorPath:@"Crash.BinaryImage.size" toSuspiciousErrorsForKey:kAMAUserInfoInvalid];
    }

    return errorFound;
}

- (BOOL)validateSystem:(AMASystem *)system
{
    BOOL errorFound = NO;

    if (system.kernelVersion == nil) {
        [self addErrorPath:@"Crash.system.kernel_version" toNonCriticalErrorsForKey:kAMAUserInfoRequired];
    }
    if (system.osBuildNumber == nil) {
        [self addErrorPath:@"Crash.system.os_build_number" toNonCriticalErrorsForKey:kAMAUserInfoRequired];
    }
    if (system.executablePath == nil) {
        [self addErrorPath:@"Crash.system.executable_path" toNonCriticalErrorsForKey:kAMAUserInfoRequired];
    }
    if (system.cpuArch == nil) {
        [self addErrorPath:@"Crash.system.cpu_arch" toNonCriticalErrorsForKey:kAMAUserInfoRequired];
    }
    if (system.processName == nil) {
        [self addErrorPath:@"Crash.system.process_name" toNonCriticalErrorsForKey:kAMAUserInfoRequired];
    }
    if (system.memory == nil) {
        [self addErrorPath:@"Crash.system.memory" toNonCriticalErrorsForKey:kAMAUserInfoRequired];
    }
    if (system.applicationStats == nil) {
        [self addErrorPath:@"Crash.system.application_stats" toNonCriticalErrorsForKey:kAMAUserInfoRequired];
    }
    if (system.bootTimestamp == nil) {
        [self addErrorPath:@"Crash.system.boot_timestamp" toNonCriticalErrorsForKey:kAMAUserInfoRequired];
    }
    if (system.appStartTimestamp == nil) {
        [self addErrorPath:@"Crash.system.app_start_timestamp" toNonCriticalErrorsForKey:kAMAUserInfoRequired];
    }

    return errorFound;
}

- (BOOL)validateCrash:(AMACrashReportCrash *)crash
{
    BOOL errorFound = NO;

    if (crash.error == nil) {
        errorFound = YES;
        [self addErrorPath:@"Crash.crash.error" toCriticalErrorsForKey:kAMAUserInfoRequired];
    }
    return errorFound;
}

- (BOOL)validateError:(AMACrashReportError *)reportError
{
    BOOL errorFound = NO;

    if (reportError.type == AMACrashTypeMachException && reportError.mach == nil) {
        errorFound = YES;
        [self addErrorPath:@"Crash.crash.error.mach" toCriticalErrorsForKey:kAMAUserInfoRequired];
    }
    if (reportError.type == AMACrashTypeSignal && reportError.signal == nil) {
        errorFound = YES;
        [self addErrorPath:@"Crash.crash.error.signal" toCriticalErrorsForKey:kAMAUserInfoRequired];
    }
    if ((reportError.type == AMACrashTypeNonFatal ||
        reportError.type == AMACrashTypeVirtualMachineError ||
        reportError.type == AMACrashTypeVirtualMachineCustomError)
        && reportError.nonFatalsChain.count == 0) {
        errorFound = YES;
        [self addErrorPath:@"Crash.crash.error.non_fatals_chain" toCriticalErrorsForKey:kAMAUserInfoRequired];
    }
    if (reportError.type == AMACrashTypeVirtualMachineCrash && reportError.virtualMachineCrash == nil) {
        errorFound = YES;
        [self addErrorPath:@"Crash.crash.error.virtual_machine_crash" toCriticalErrorsForKey:kAMAUserInfoRequired];
    }
    return errorFound;
}

- (BOOL)validateRegister:(AMARegister *)amaRegister
{
    BOOL errorFound = NO;

    if (amaRegister.name == nil) {
        errorFound = YES;
        [self addErrorPath:@"Crash.crash.threads.registers.name" toNonCriticalErrorsForKey:kAMAUserInfoRequired];
    }

    return errorFound;
}

- (BOOL)validateMemory:(AMAMemory *)memory
{
    if (memory.usable == 0) {
        [self addErrorPath:@"Crash.system.memory.usable" toSuspiciousErrorsForKey:kAMAUserInfoInvalid];
    }
    if (memory.free == 0) {
        [self addErrorPath:@"Crash.system.memory.free" toSuspiciousErrorsForKey:kAMAUserInfoInvalid];
    }
    if (memory.size == 0) {
        [self addErrorPath:@"Crash.system.memory.size" toSuspiciousErrorsForKey:kAMAUserInfoInvalid];
    }

    return NO;
}

- (BOOL)validateAppStats:(AMAApplicationStatistics *)statistics
{
    if (statistics.activeTimeSinceLaunch == 0) {
        [self addErrorPath:@"Crash.system.application_stats.active_time_since_launch"
  toSuspiciousErrorsForKey:kAMAUserInfoInvalid];
    }
    return NO;
}

- (BOOL)validateBacktraceFrame:(AMABacktraceFrame *)frame
{
    return NO;
}

#pragma mark - Private

- (void)addErrorPath:(NSString *)error toCriticalErrorsForKey:(NSString *)key
{
    [self addErrorPath:error toDictionary:self.criticalErrors forKey:key];
    self.highestError = MAX(AMACrashValidatorErrorCodeCritical, self.highestError);
}

- (void)addErrorPath:(NSString *)error toSuspiciousErrorsForKey:(NSString *)key
{
    [self addErrorPath:error toDictionary:self.suspiciousErrors forKey:key];
    self.highestError = MAX(AMACrashValidatorErrorCodeSuspicious, self.highestError);
}

- (void)addErrorPath:(NSString *)error toNonCriticalErrorsForKey:(NSString *)key
{
    [self addErrorPath:error toDictionary:self.nonCriticalErrors forKey:key];
    self.highestError = MAX(AMACrashValidatorErrorCodeNonCritical, self.highestError);
}

- (void)addErrorPath:(NSString *)error toDictionary:(NSMutableDictionary *)dictionary forKey:(NSString *)key
{
    if (dictionary[key] == nil) {
        dictionary[key] = [NSMutableArray array];
    }
    [dictionary[key] addObject:error];
}
@end
