
#import "AMACrashLogging.h"
#import "AMAExceptionFormatter.h"
#import "AMABacktrace.h"
#import "AMABacktraceFrame.h"
#import "AMABacktraceSymbolicator.h"
#import "AMABinaryImage.h"
#import "AMACrashObjectsFactory.h"
#import "AMACrashReportCrash.h"
#import "AMACrashReportDecoder.h"
#import "AMACrashReportError.h"
#import "AMADecodedCrash.h"
#import "AMADecodedCrashSerializer.h"
#import "AMAErrorCustomData.h"
#import "AMAErrorModel.h"
#import "AMAErrorModelFactory.h"
#import "AMAInfo.h"
#import "AMAKSCrash.h"
#import "AMAMach.h"
#import "AMANSException.h"
#import "AMANonFatal.h"
#import "AMAPluginErrorDetails.h"
#import "AMASignal.h"
#import "AMAThread.h"
#import "AMAVirtualMachineCrash.h"
#import "AMAVirtualMachineError.h"
#import "AMAVirtualMachineInfo.h"
#import "AMAKSCrashImports.h"
#import <mach/exception.h>

static NSString *const kAMAKSCrashReporterVersion = @"3.2.0";

@interface AMAExceptionFormatter ()

@property (nonatomic, strong, readonly) id<AMADateProviding> dateProvider;
@property (nonatomic, strong, readonly) AMADecodedCrashSerializer *serializer;
@property (nonatomic, strong, readonly) AMABacktraceSymbolicator *symbolicator;
@property (nonatomic, strong, readonly) AMACrashReportDecoder *decoder;

@end

@implementation AMAExceptionFormatter

- (instancetype)init
{
    return [self initWithDateProvider:[[AMADateProvider alloc] init]
                           serializer:[[AMADecodedCrashSerializer alloc] init]
                         symbolicator:[[AMABacktraceSymbolicator alloc] init]
                              decoder:[[AMACrashReportDecoder alloc] init]];
}

- (instancetype)initWithDateProvider:(id<AMADateProviding>)dateProvider
                          serializer:(AMADecodedCrashSerializer *)serializer
                        symbolicator:(AMABacktraceSymbolicator *)symbolicator
                             decoder:(AMACrashReportDecoder *)decoder
{
    self = [super init];
    if (self != nil) {
        _serializer = serializer;
        _dateProvider = dateProvider;
        _symbolicator = symbolicator;
        _decoder = decoder;
    }
    return self;
}
/**
 * This function is currently unused but may be useful. Used for legacy NSString errors.
 */
- (NSData *)formattedException:(NSException *)exception error:(NSError **)error
{
    NSSet *binaryImages = nil;
    AMABacktrace *backtrace = [self.symbolicator backtraceForInstructionAddresses:exception.callStackReturnAddresses
                                                                     binaryImages:&binaryImages];
    AMANSException *nsException = [[AMANSException alloc] initWithName:exception.name
                                                              userInfo:exception.userInfo.description];

    uint64_t faultAddress = [backtrace.frames.firstObject.instructionAddress unsignedLongLongValue];
    AMACrashReportError *reportRrror = [[AMACrashReportError alloc] initWithAddress:faultAddress
                                                                             reason:exception.reason
                                                                               type:AMACrashTypeNsException
                                                                               mach:[self deafultMachError]
                                                                             signal:[self defaultSignalError]
                                                                        nsexception:nsException
                                                                       cppException:nil
                                                                     nonFatalsChain:nil
                                                                virtualMachineCrash:nil];

    AMADecodedCrash *decodedCrash = [self decodedCrashWithBacktrace:backtrace
                                                              error:reportRrror
                                                       binaryImages:binaryImages
                                                 virtualMachineInfo:nil];

    return [self.serializer dataForCrash:decodedCrash error:error];
}

- (NSData *)formattedError:(AMAErrorModel *)errorModel error:(NSError **)error
{
    if (errorModel == nil) {
        return nil;
    }
    NSMutableSet *binaryImages = [NSMutableSet set];
    NSArray<AMANonFatal *> *nonFatalsChain = [self nonFatalsChainForErrorModel:errorModel binaryImages:binaryImages];
    
    NSSet *reportCallBinaryImages = nil;
    AMABacktrace *callBacktrace = [self.symbolicator backtraceForInstructionAddresses:errorModel.reportCallBacktrace
                                                                         binaryImages:&reportCallBinaryImages];
    [binaryImages unionSet:reportCallBinaryImages];
    
    uint64_t faultAddress =
        [nonFatalsChain.firstObject.backtrace.frames.firstObject.instructionAddress unsignedLongLongValue];
    AMACrashReportError *crashReportError =
        [[AMACrashReportError alloc] initWithAddress:faultAddress
                                              reason:nil
                                                type:AMACrashTypeNonFatal
                                                mach:[self deafultMachError]
                                              signal:[self defaultSignalError]
                                         nsexception:nil
                                        cppException:nil
                                      nonFatalsChain:nonFatalsChain
                                 virtualMachineCrash:nil];
    
    AMADecodedCrash *decodedCrash = [self decodedCrashWithBacktrace:callBacktrace
                                                              error:crashReportError
                                                       binaryImages:binaryImages
                                                 virtualMachineInfo:nil];
    return [self.serializer dataForCrash:decodedCrash error:error];
}

- (NSData *)formattedCrashErrorDetails:(AMAPluginErrorDetails *)errorDetails
                        bytesTruncated:(NSUInteger *)bytesTruncated
                                 error:(NSError **)error
{
    AMACrashObjectsFactory *crashObjectsFactory = [AMACrashObjectsFactory sharedInstance];
    AMAVirtualMachineInfo *virtualMachineInfo = [crashObjectsFactory virtualMachineInfoForErrorDetails:errorDetails
                                                                                        bytesTruncated:bytesTruncated];
    AMABacktrace *backtrace = [crashObjectsFactory backtraceFrom:errorDetails.backtrace bytesTruncated:bytesTruncated];
    AMAVirtualMachineCrash *virtualMachineCrash = [crashObjectsFactory virtualMachineCrashForErrorDetails:errorDetails
                                                                                           bytesTruncated:bytesTruncated];
    AMACrashReportError *reportError =
        [[AMACrashReportError alloc] initWithAddress:0x0
                                              reason:nil
                                                type:AMACrashTypeVirtualMachineCrash
                                                mach:nil
                                              signal:nil
                                         nsexception:nil
                                        cppException:nil
                                      nonFatalsChain:nil
                                 virtualMachineCrash:virtualMachineCrash];
    AMADecodedCrash *decodedCrash = [self decodedCrashWithBacktrace:backtrace
                                                              error:reportError
                                                       binaryImages:[NSSet new]
                                                 virtualMachineInfo:virtualMachineInfo];
    return [self.serializer dataForCrash:decodedCrash error:error];
}

- (NSData *)formattedErrorErrorDetails:(AMAPluginErrorDetails *)errorDetails
                        bytesTruncated:(NSUInteger *)bytesTruncated
                                 error:(NSError **)error
{
    AMACrashObjectsFactory *crashObjectsFactory = [AMACrashObjectsFactory sharedInstance];
    AMABacktrace *backtrace = [crashObjectsFactory backtraceFrom:errorDetails.backtrace bytesTruncated:bytesTruncated];
    AMAVirtualMachineInfo *virtualMachineInfo = [crashObjectsFactory virtualMachineInfoForErrorDetails:errorDetails
                                                                                        bytesTruncated:bytesTruncated];
    AMAErrorModel *errorModel = [[AMAErrorModelFactory sharedInstance] defaultModelForErrorDetails:errorDetails
                                                                                    bytesTruncated:bytesTruncated];
    AMANonFatal *nonFatal = [[AMANonFatal alloc] initWithModel:errorModel
                                                     backtrace:backtrace];
    AMACrashReportError *reportError =
        [[AMACrashReportError alloc] initWithAddress:0x0
                                              reason:nil
                                                type:AMACrashTypeVirtualMachineError
                                                mach:nil
                                              signal:nil
                                         nsexception:nil
                                        cppException:nil
                                      nonFatalsChain:@[ nonFatal ]
                                 virtualMachineCrash:nil];
    AMADecodedCrash *decodedCrash = [self decodedCrashWithBacktrace:nil
                                                              error:reportError
                                                       binaryImages:[NSSet set]
                                                 virtualMachineInfo:virtualMachineInfo];
    return [self.serializer dataForCrash:decodedCrash error:error];
}

- (NSData *)formattedCustomErrorErrorDetails:(AMAPluginErrorDetails *)errorDetails
                                  identifier:(NSString *)identifier
                              bytesTruncated:(NSUInteger *)bytesTruncated
                                       error:(NSError **)error
{
    AMACrashObjectsFactory *crashObjectsFactory = [AMACrashObjectsFactory sharedInstance];
    AMABacktrace *backtrace = [crashObjectsFactory backtraceFrom:errorDetails.backtrace bytesTruncated:bytesTruncated];
    AMAVirtualMachineInfo *virtualMachineInfo = [crashObjectsFactory virtualMachineInfoForErrorDetails:errorDetails
                                                                                        bytesTruncated:bytesTruncated];
    AMAErrorModel *errorModel = [[AMAErrorModelFactory sharedInstance] customModelForErrorDetails:errorDetails
                                                                                       identifier:identifier
                                                                                   bytesTruncated:bytesTruncated];
    AMANonFatal *nonFatal = [[AMANonFatal alloc] initWithModel:errorModel
                                                     backtrace:backtrace];
    AMACrashReportError *reportError =
        [[AMACrashReportError alloc] initWithAddress:0x0
                                              reason:nil
                                                type:AMACrashTypeVirtualMachineCustomError
                                                mach:nil
                                              signal:nil
                                         nsexception:nil
                                        cppException:nil
                                      nonFatalsChain:@[ nonFatal ]
                                 virtualMachineCrash:nil];
    AMADecodedCrash *decodedCrash = [self decodedCrashWithBacktrace:nil
                                                              error:reportError
                                                       binaryImages:[NSSet new]
                                                 virtualMachineInfo:virtualMachineInfo];
    return [self.serializer dataForCrash:decodedCrash error:error];
}

- (NSArray *)nonFatalsChainForErrorModel:(AMAErrorModel *)error binaryImages:(NSMutableSet *)binaryImages
{
    if (error == nil) {
        return @[];
    }
    NSMutableArray *nonFatalsChain = [NSMutableArray array];
    AMAErrorModel *currentError = error;
    while (currentError != nil) {
        NSSet *currentBinaryImages = nil;
        AMABacktrace *backtrace = [self.symbolicator backtraceForInstructionAddresses:currentError.userProvidedBacktrace
                                                                         binaryImages:&currentBinaryImages];
        if (currentBinaryImages != nil) {
            [binaryImages unionSet:currentBinaryImages];
        }
        AMANonFatal *nonFatal = [[AMANonFatal alloc] initWithModel:currentError backtrace:backtrace];
        [nonFatalsChain addObject:nonFatal];
        currentError = currentError.underlyingError;
    }
    return [nonFatalsChain copy];
}

- (AMAMach *)deafultMachError
{
    return [[AMAMach alloc] initWithExceptionType:EXC_CRASH
                                             code:0
                                          subcode:0];
}

- (AMASignal *)defaultSignalError
{
    return [[AMASignal alloc] initWithSignal:SIGABRT code:0];
}

- (AMADecodedCrash *)decodedCrashWithBacktrace:(AMABacktrace *)backtrace
                                         error:(AMACrashReportError *)error
                                  binaryImages:(NSSet<AMABinaryImage *> *)binaryImages
                            virtualMachineInfo:(AMAVirtualMachineInfo *)virtualMachineInfo
{
    AMAInfo *info = [[AMAInfo alloc] initWithVersion:kAMAKSCrashReporterVersion
                                          identifier:[[NSUUID UUID] UUIDString]
                                           timestamp:[self.dateProvider currentDate]
                                  virtualMachineInfo:virtualMachineInfo];

    NSDictionary *systemInfo = KSCrash.sharedInstance.systemInfo;
    AMASystem *system = [self.decoder systemInfoForDictionary:systemInfo];

    NSArray *threads = nil;
    if (backtrace != nil) {
        AMAThread *thread = [[AMAThread alloc] initWithBacktrace:backtrace
                                                       registers:nil
                                                           stack:nil
                                                           index:0
                                                         crashed:YES
                                                      threadName:nil
                                                       queueName:nil];
        threads = @[ thread ];
    }

    NSArray *binaryImagesArray = [binaryImages.allObjects sortedArrayUsingSelector:@selector(compare:)];

    AMACrashReportCrash *crash = [[AMACrashReportCrash alloc] initWithError:error threads:threads];

    return [[AMADecodedCrash alloc] initWithAppState:nil
                                         appBuildUID:nil
                                    errorEnvironment:nil
                                      appEnvironment:nil
                                                info:info
                                        binaryImages:binaryImagesArray
                                              system:system
                                               crash:crash];
}

@end
