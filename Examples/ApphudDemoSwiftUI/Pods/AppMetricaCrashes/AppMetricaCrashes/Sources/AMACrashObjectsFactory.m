
#import "AMACrashLogging.h"
#import "AMACrashObjectsFactory.h"

#import "AMABacktrace.h"
#import "AMABacktraceFrame.h"
#import "AMAEnvironmentTruncator.h"
#import "AMAPluginErrorDetails.h"
#import "AMAStackTraceElement.h"
#import "AMAVirtualMachineCrash.h"
#import "AMAVirtualMachineInfo.h"

@interface AMACrashObjectsFactory ()

@property (nonatomic, strong, readonly) id<AMAStringTruncating> messageTruncator;
@property (nonatomic, strong, readonly) id<AMAStringTruncating> shortStringTruncator;
@property (nonatomic, strong, readonly) id<AMADictionaryTruncating> environmentTruncator;
@property (nonatomic, assign, readonly) NSUInteger maxBacktraceFramesCount;

@end

@implementation AMACrashObjectsFactory

- (instancetype)init
{
    return [self initWithMessageTruncator:[[AMALengthStringTruncator alloc] initWithMaxLength:1000]
                     environmentTruncator:[[AMAEnvironmentTruncator alloc] init]
                     shortStringTruncator:[[AMALengthStringTruncator alloc] initWithMaxLength:100]
                  maxBacktraceFramesCount:200];
}

- (instancetype)initWithMessageTruncator:(id<AMAStringTruncating>)messageTruncator
                    environmentTruncator:(id<AMADictionaryTruncating>)environmentTruncatror
                    shortStringTruncator:(id<AMAStringTruncating>)shortStringTruncator
                 maxBacktraceFramesCount:(NSUInteger)maxBacktraceFramesCount
{
    self = [super init];
    if (self != nil) {
        _messageTruncator = messageTruncator;
        _environmentTruncator = environmentTruncatror;
        _shortStringTruncator = shortStringTruncator;
        _maxBacktraceFramesCount = maxBacktraceFramesCount;
    }
    return self;
}

+ (instancetype)sharedInstance
{
    static AMACrashObjectsFactory *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AMACrashObjectsFactory alloc] init];
    });
    return instance;
}

- (AMAVirtualMachineInfo *)virtualMachineInfoForErrorDetails:(AMAPluginErrorDetails *)errorDetails
                                              bytesTruncated:(NSUInteger *)bytesTruncated
{
    if (errorDetails == nil) {
        return nil;
    }
    NSString *truncatedPlatform =
        [self.shortStringTruncator truncatedString:errorDetails.platform onTruncation:^(NSUInteger newBytesTruncated) {
            AMALogWarn(@"Platform truncated by %lu symbols", (unsigned long) newBytesTruncated);
            [self onTruncation:bytesTruncated bytesTruncated:newBytesTruncated];
        }];
    NSString *truncatedVirtualMachineVersion =
        [self.shortStringTruncator truncatedString:errorDetails.virtualMachineVersion onTruncation:^(NSUInteger newBytesTruncated) {
            AMALogWarn(@"Virtual machine version truncated by %lu symbols", (unsigned long) newBytesTruncated);
            [self onTruncation:bytesTruncated bytesTruncated:newBytesTruncated];
        }];
    NSDictionary *truncatedEnvironment = [self.environmentTruncator
        truncatedDictionary:errorDetails.pluginEnvironment
               onTruncation:^(NSUInteger newBytesTruncated) {
                   [self onTruncation:bytesTruncated
                       bytesTruncated:newBytesTruncated];
               }];
    return [[AMAVirtualMachineInfo alloc] initWithPlatform:truncatedPlatform
                                                   version:truncatedVirtualMachineVersion
                                               environment:truncatedEnvironment];
}

- (AMAVirtualMachineCrash *)virtualMachineCrashForErrorDetails:(AMAPluginErrorDetails *)errorDetails
                                                bytesTruncated:(NSUInteger *)bytesTruncated;
{
    if (errorDetails == nil) {
        return nil;
    }
    NSString *truncatedMessage =
        [self.messageTruncator truncatedString:errorDetails.message onTruncation:^(NSUInteger newBytesTruncated) {
            AMALogWarn(@"Error message truncated by %lu symbols", (unsigned long) newBytesTruncated);
            [self onTruncation:bytesTruncated bytesTruncated:newBytesTruncated];
        }];
    NSString *truncatedExceptionClass =
        [self.shortStringTruncator truncatedString:errorDetails.exceptionClass onTruncation:^(NSUInteger newBytesTruncated) {
            AMALogWarn(@"Exception class truncated by %lu symbols", (unsigned long) newBytesTruncated);
            [self onTruncation:bytesTruncated bytesTruncated:newBytesTruncated];
        }];

    return [[AMAVirtualMachineCrash alloc] initWithClassName:truncatedExceptionClass message:truncatedMessage];
}

- (AMABacktrace *)backtraceFrom:(NSArray<AMAStackTraceElement *> *)originalBacktrace
                 bytesTruncated:(NSUInteger *)bytesTruncated
{
    NSMutableArray<AMABacktraceFrame *> *frames = [NSMutableArray array];
    if (originalBacktrace.count > self.maxBacktraceFramesCount) {
        size_t diff = originalBacktrace.count - self.maxBacktraceFramesCount;
        AMALogWarn(@"Backtrace truncated by %zu elements", diff);
        [self onTruncation:bytesTruncated bytesTruncated: diff * sizeof(uintptr_t)];
    }
    BOOL __block elementTruncated = NO;
    [originalBacktrace enumerateObjectsUsingBlock:^(AMAStackTraceElement *element, NSUInteger idx, BOOL *stop) {
        if (idx >= self.maxBacktraceFramesCount) {
            *stop = YES;
        } else {
            NSString *truncatedClassName =
                [self.shortStringTruncator truncatedString:element.className onTruncation:^(NSUInteger newBytesTruncated) {
                    elementTruncated = YES;
                    [self onTruncation:bytesTruncated bytesTruncated:newBytesTruncated];
                }];
            NSString *truncatedMethodName =
                [self.shortStringTruncator truncatedString:element.methodName onTruncation:^(NSUInteger newBytesTruncated) {
                    elementTruncated = YES;
                    [self onTruncation:bytesTruncated bytesTruncated:newBytesTruncated];
                }];
            NSString *truncatedFileName =
                [self.shortStringTruncator truncatedString:element.fileName onTruncation:^(NSUInteger newBytesTruncated) {
                    elementTruncated = YES;
                    [self onTruncation:bytesTruncated bytesTruncated:newBytesTruncated];
                }];
            AMABacktraceFrame *frame =
                [[AMABacktraceFrame alloc] initWithClassName:truncatedClassName
                                                  methodName:truncatedMethodName
                                                  lineOfCode:element.line
                                                columnOfcode:element.column
                                              sourceFileName:truncatedFileName];
            [frames addObject:frame];
        }
    }];
    if (elementTruncated) {
        AMALogWarn(@"Some backtrace elements were truncated");
    }
    return [[AMABacktrace alloc] initWithFrames:frames.copy];
}

- (void)onTruncation:(NSUInteger *)counter bytesTruncated:(NSUInteger)bytesTruncated
{
    if (counter != NULL) {
        *counter += bytesTruncated;
    }
}

@end
