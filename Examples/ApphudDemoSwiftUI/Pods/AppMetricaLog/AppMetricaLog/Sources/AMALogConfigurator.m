
#include <sys/sysctl.h>
#import <AppMetricaLog/AppMetricaLog.h>
#import "AMAASLLogMiddleware.h"
#import "AMATTYLogMiddleware.h"
#import "AMAOSLogMiddleware.h"
#import "AMALogFileManager.h"
#import "AMALogMessageFormatterFactory.h"
#import "AMALogFileRotation.h"
#import "AMALogFileFactory.h"
#import "AMAFileLogMiddleware.h"
#import "AMALogOutput.h"
#import "AMALogOutputFactory.h"

static const AMALogLevel AMALogControllerDefaultLogLevelMask = AMALogLevelError | AMALogLevelNotify;
static const AMALogLevel AMALogControllerEnabledLogLevelMask = AMALogLevelInfo | AMALogLevelWarning | AMALogLevelError | AMALogLevelNotify;

#ifdef AMA_ENABLE_FILE_LOG
static NSString *const AMALogControllerLogsDirectory = @"io.appmetrica.logs";
static NSString *const AMALogControllerLogPrefix = @"io_appmetrica";

static const NSUInteger AMALogControllerMaxAllowedLogFilesCount = 20;
#endif

@interface AMALogConfigurator ()

@property (nonatomic, strong) AMALogFacade *log;

@property (nonatomic, strong) id<AMALogMiddleware> aslMiddleware;
@property (nonatomic, strong) id<AMALogMiddleware> ttyMiddleware;
@property (nonatomic, strong) id<AMALogMiddleware> fileMiddleware;
@property (nonatomic, strong) NSMutableDictionary<AMALogChannel, id<AMALogMiddleware>> *osMiddleware;

@property (nonatomic, strong, readonly) NSMutableSet *configuredChannels;

@property (nonatomic, copy) NSString *logsDirectory;

@property (nonatomic, strong, readonly) AMALogMessageFormatterFactory *formatterFactory;
@property (nonatomic, strong, readonly) AMALogOutputFactory *logOutputFactory;

@end

@implementation AMALogConfigurator

- (instancetype)init
{
    return [self initWithLog:[AMALogFacade sharedLog]];
}

- (instancetype)initWithLog:(AMALogFacade *)log
{
    return [self initWithLog:log
            logOutputFactory:[[AMALogOutputFactory alloc] init]
            formatterFactory:[AMALogMessageFormatterFactory new]
    ];
}

- (instancetype)initWithLog:(AMALogFacade *)log
           logOutputFactory:(AMALogOutputFactory *)outputFactory
           formatterFactory:(AMALogMessageFormatterFactory *)formatterFactory
{
    self = [super init];
    if (self != nil) {
        _log = log;
        _formatterFactory = formatterFactory;
        _configuredChannels = [NSMutableSet set];
        _logOutputFactory = outputFactory;
        _osMiddleware = [NSMutableDictionary dictionary];
    }
    
    return self;
}

#pragma mark - Tune

- (void)setChannel:(AMALogChannel)channel enabled:(BOOL)enabled
{
    @synchronized (self) {
        AMALogLevel level = [self levelMaskForLogEnabled:enabled];
        [self updateLogLevel:level ofChannel:channel];
    }
}

- (void)updateLogLevel:(AMALogLevel)level ofChannel:(AMALogChannel)channel
{
    for (AMALogOutput *output in [self.log outputsWithChannel:channel]) {
        [self.log removeOutput:output];
        
        AMALogOutput *updatedOutput = [output outputByChangingLogLevel:level];
        [self.log addOutput:updatedOutput];
    }
}

- (AMALogLevel)levelMaskForLogEnabled:(BOOL)enabled
{
    return enabled ? AMALogControllerEnabledLogLevelMask : AMALogControllerDefaultLogLevelMask;
}

- (BOOL)isDebuggerAttached
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

- (AMALogOutput *)outputForChannel:(AMALogChannel)channel
                            format:(NSArray *)format
                        middleware:(id<AMALogMiddleware>)middleware
{
    return [self.logOutputFactory outputWithChannel:channel
                                              level:AMALogControllerDefaultLogLevelMask
                                          formatter:[self.formatterFactory formatterWithFormatParts:format]
                                         middleware:middleware];
}

#pragma mark - Setup

- (void)setupLogWithChannel:(AMALogChannel)channel
{
    @synchronized (self) {
        if ([self.configuredChannels containsObject:channel]) {
            return;
        }
        [self.configuredChannels addObject:channel];
    }

    NSMutableArray *outputs = [NSMutableArray array];
    BOOL shouldAddTTYLog = YES;

    id<AMALogMiddleware> osMiddleware = [self osMiddleWareWithChannel:channel];
    if (osMiddleware != nil) {
        [outputs addObject:[self osOutputWithChannel:channel middleware:osMiddleware]];
        shouldAddTTYLog = [self isDebuggerAttached] == NO;
    }
    else {
        [outputs addObject:[self aslOutputWithChannel:channel]];
    }
    if (shouldAddTTYLog) {
        [outputs addObject:[self ttyOutputWithChannel:channel]];
    }
#ifdef AMA_ENABLE_FILE_LOG
    AMALogOutput *output = [self fileOutputWithChannel:channel];
    [outputs addObject:output];
#endif // AMA_ENABLE_FILE_LOG

    for (AMALogOutput *output in outputs) {
        [self.log addOutput:output];
    }
}

#pragma mark - Output

- (AMALogOutput *)osOutputWithChannel:(AMALogChannel)channel middleware:osMiddleware
{
    NSArray *format = @[
        @(AMALogFormatPartOrigin),
        @(AMALogFormatPartContent),
        @(AMALogFormatPartBacktrace)
    ];
    return [self outputForChannel:channel format:format middleware:osMiddleware];
}

- (AMALogOutput *)aslOutputWithChannel:(AMALogChannel)channel
{
    NSArray *format = @[
        @(AMALogFormatPartPublicPrefix),
        @(AMALogFormatPartOrigin),
        @(AMALogFormatPartContent),
        @(AMALogFormatPartBacktrace)
    ];
    return [self outputForChannel:channel format:format middleware:self.aslMiddleware];
}

- (AMALogOutput *)ttyOutputWithChannel:(AMALogChannel)channel
{
    NSArray *format = @[
        @(AMALogFormatPartDate),
        @(AMALogFormatPartOrigin),
        @(AMALogFormatPartContent),
        @(AMALogFormatPartBacktrace)
    ];
    return [self outputForChannel:channel format:format middleware:self.ttyMiddleware];
}

#ifdef AMA_ENABLE_FILE_LOG
- (AMALogOutput *)fileOutputWithChannel:(AMALogChannel)channel
{
    NSArray *fileFormat = @[
        @(AMALogFormatPartDate),
        @(AMALogFormatPartOrigin),
        @(AMALogFormatPartContent),
        @(AMALogFormatPartBacktrace)
    ];
    return [self outputForChannel:channel format:fileFormat middleware:self.fileMiddleware];
}
#endif // AMA_ENABLE_FILE_LOG

#pragma mark - Middleware

- (id<AMALogMiddleware>)aslMiddleware
{
    @synchronized (self) {
        if (_aslMiddleware == nil) {
            _aslMiddleware = [AMAASLLogMiddleware new];
        }
        return _aslMiddleware;
    }
}

- (id<AMALogMiddleware>)ttyMiddleware
{
    @synchronized (self) {
        if (_ttyMiddleware == nil) {
            _ttyMiddleware = [AMATTYLogMiddleware new];
        }
        return _ttyMiddleware;
    }
}

- (id<AMALogMiddleware>)osMiddleWareWithChannel:(AMALogChannel)channel
{
    @synchronized (self) {
        if (self.osMiddleware[channel] == nil) {
            self.osMiddleware[channel] = [self osMiddlewareWithCategory:channel.UTF8String];
        }
        return self.osMiddleware[channel];
    }
}

- (id<AMALogMiddleware>)osMiddlewareWithCategory:(const char *)category
{
    id<AMALogMiddleware> middleware = nil;
    if (@available(iOS 10.0, tvOS 10.0, *)) {
        middleware = [[AMAOSLogMiddleware alloc] initWithCategory:category];
    }
    return middleware;
}

#ifdef AMA_ENABLE_FILE_LOG
- (id<AMALogMiddleware>)fileMiddleware
{
    @synchronized (self) {
        if (_fileMiddleware == nil) {
            AMALogFileFactory *logFileFactory = [[AMALogFileFactory alloc] initWithPrefix:AMALogControllerLogPrefix];

            AMALogFileManager *fileManager = [[AMALogFileManager alloc] initWithLogsDirectory:self.logsDirectory
                                                                               logFileFactory:logFileFactory];

            NSArray *logFiles = [fileManager retrieveLogFiles];
            AMALogFileRotation *rotation = [AMALogFileRotation rotationForLogFiles:logFiles
                                                               withMaxFilesAllowed:AMALogControllerMaxAllowedLogFilesCount];

            [fileManager removeLogFiles:rotation.filesToRemove];

            AMALogFile *file = [logFileFactory logFileWithSerialNumber:rotation.nextSerialNumber];
            NSFileHandle *fileHandle = [fileManager fileHandleForLogFile:file];

            _fileMiddleware = [[AMAFileLogMiddleware alloc] initWithFileHandle:fileHandle];
        }
        return _fileMiddleware;
    }
}

- (NSString *)logsDirectory
{
    if (_logsDirectory == nil) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        _logsDirectory = [[paths firstObject] stringByAppendingPathComponent:AMALogControllerLogsDirectory];
    }

    return _logsDirectory;
}
#endif // AMA_ENABLE_FILE_LOG

@end
