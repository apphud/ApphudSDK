
#import "AMAErrorModelFactory.h"

#import "AMAErrorModel.h"
#import "AMAErrorNSErrorData.h"
#import "AMAErrorCustomData.h"
#import "AMAError.h"
#import "AMAPluginErrorDetails.h"
#import "AMAVirtualMachineError.h"
#import "AMAEnvironmentTruncator.h"

@interface AMAErrorModelFactory ()

@property (nonatomic, strong, readonly) id<AMAStringTruncating> domainTruncator;
@property (nonatomic, strong, readonly) id<AMAStringTruncating> identifierTruncator;
@property (nonatomic, strong, readonly) id<AMAStringTruncating> messageTruncator;
@property (nonatomic, strong, readonly) id<AMADictionaryTruncating> environmentTruncator;
@property (nonatomic, strong, readonly) id<AMAStringTruncating> shortStringTruncator;
@property (nonatomic, assign, readonly) NSUInteger maxUnderlyingErrorsCount;
@property (nonatomic, assign, readonly) NSUInteger maxBacktraceFramesCount;

@end

@implementation AMAErrorModelFactory

- (instancetype)init
{
    return [self initWithDomainTruncator:[[AMALengthStringTruncator alloc] initWithMaxLength:200]
                     identifierTruncator:[[AMALengthStringTruncator alloc] initWithMaxLength:300]
                        messageTruncator:[[AMALengthStringTruncator alloc] initWithMaxLength:1000]
                    environmentTruncator:[[AMAEnvironmentTruncator alloc] init]
                    shortStringTruncator:[[AMALengthStringTruncator alloc] initWithMaxLength:100]
                maxUnderlyingErrorsCount:10
                 maxBacktraceFramesCount:200];
}

- (instancetype)initWithDomainTruncator:(id<AMAStringTruncating>)domainTruncator
                    identifierTruncator:(id<AMAStringTruncating>)identifierTruncator
                       messageTruncator:(id<AMAStringTruncating>)messageTruncator
                   environmentTruncator:(id<AMADictionaryTruncating>)environmentTruncator
                   shortStringTruncator:(id<AMAStringTruncating>)shortStringTruncator
               maxUnderlyingErrorsCount:(NSUInteger)maxUnderlyingErrorsCount
                maxBacktraceFramesCount:(NSUInteger)maxBacktraceFramesCount
{
    self = [super init];
    if (self != nil) {
        _domainTruncator = domainTruncator;
        _identifierTruncator = identifierTruncator;
        _messageTruncator = messageTruncator;
        _environmentTruncator = environmentTruncator;
        _shortStringTruncator = shortStringTruncator;
        _maxUnderlyingErrorsCount = maxUnderlyingErrorsCount;
        _maxBacktraceFramesCount = maxBacktraceFramesCount;
    }
    return self;
}

+ (instancetype)sharedInstance
{
    static AMAErrorModelFactory *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AMAErrorModelFactory alloc] init];
    });
    return instance;
}

- (AMAErrorModel *)modelForNSError:(NSError *)error options:(AMAErrorReportingOptions)options
{
    return [self modelForNSError:error options:options index:0];
}

- (AMAErrorModel *)modelForNSError:(NSError *)error options:(AMAErrorReportingOptions)options index:(NSUInteger)index
{
    if (error == nil || [error isKindOfClass:[NSError class]] == NO) {
        return nil;
    }
    if (index == self.maxUnderlyingErrorsCount) {
        AMALogWarn(@"Underlying errors count reached");
        return nil;
    }

    NSUInteger __block globalBytesTruncated = 0;
    NSString *domain = [self.domainTruncator truncatedString:error.domain onTruncation:^(NSUInteger bytesTruncated) {
        AMALogWarn(@"Error domain truncated");
        globalBytesTruncated += bytesTruncated;
    }];
    AMAErrorNSErrorData *data = [[AMAErrorNSErrorData alloc] initWithDomain:domain code:error.code];

    NSMutableDictionary *parameters = [error.userInfo mutableCopy];
    parameters[NSUnderlyingErrorKey] = nil;
    parameters[AMABacktraceErrorKey] = nil;
    NSString *parametersString = [self parametersStringForDictionary:parameters bytesTruncated:&globalBytesTruncated];

    NSArray *reportCallBacktrace = [self limitedBacktrace:[self reportCallBacktraceForOptions:options]
                                           bytesTruncated:&globalBytesTruncated];
    NSArray *userProvidedBacktrace =
        [self limitedBacktrace:[self validatedBacktrace:error.userInfo[AMABacktraceErrorKey]]
                bytesTruncated:&globalBytesTruncated];

    AMAErrorModel *underlyingError = [self modelForNSError:error.userInfo[NSUnderlyingErrorKey]
                                                   options:options | AMAErrorReportingOptionsNoBacktrace
                                                     index:index + 1];

    return [[AMAErrorModel alloc] initWithType:AMAErrorModelTypeNSError
                                    customData:nil
                                   nsErrorData:data
                              parametersString:parametersString
                           reportCallBacktrace:reportCallBacktrace
                         userProvidedBacktrace:userProvidedBacktrace
                           virtualMachineError:nil
                               underlyingError:underlyingError
                                bytesTruncated:globalBytesTruncated + underlyingError.bytesTruncated];
}

- (AMAErrorModel *)defaultModelForErrorDetails:(AMAPluginErrorDetails *)details
                                bytesTruncated:(NSUInteger *)bytesTruncated
{
    AMAVirtualMachineError *virtualMachineError = nil;
    if (details != nil) {
        NSString *truncatedMessage =
            [self.messageTruncator truncatedString:details.message onTruncation:^(NSUInteger newBytesTruncated) {
                AMALogWarn(@"Error message truncated by %lu symbols", (unsigned long) newBytesTruncated);
                [self onTruncation:bytesTruncated bytesTruncated:newBytesTruncated];
            }];
        NSString *truncatedExceptionClass =
            [self.shortStringTruncator truncatedString:details.exceptionClass onTruncation:^(NSUInteger newBytesTruncated) {
                AMALogWarn(@"Exception class truncated by %lu symbols", (unsigned long) newBytesTruncated);
                [self onTruncation:bytesTruncated bytesTruncated:newBytesTruncated];
            }];
        virtualMachineError = [[AMAVirtualMachineError alloc] initWithClassName:truncatedExceptionClass
                                                                        message:truncatedMessage];
    }
    NSUInteger totalBytesTruncated = bytesTruncated == NULL ? 0 : *bytesTruncated;
    AMALogInfo(@"Total bytes truncated: %lu", (unsigned long) totalBytesTruncated);
    AMAErrorModel *errorModel = [[AMAErrorModel alloc] initWithType:AMAErrorModelTypeVirtualMachine
                                                         customData:nil
                                                        nsErrorData:nil
                                                   parametersString:nil
                                                reportCallBacktrace:nil
                                              userProvidedBacktrace:nil
                                                virtualMachineError:virtualMachineError
                                                    underlyingError:nil
                                                     bytesTruncated:totalBytesTruncated];
    return errorModel;
}

- (AMAErrorModel *)customModelForErrorDetails:(AMAPluginErrorDetails *)details
                                   identifier:(NSString *)identifier
                               bytesTruncated:(NSUInteger *)bytesTruncated
{
    NSString *truncatedIdentifier =
        [self.identifierTruncator truncatedString:identifier onTruncation:^(NSUInteger newBytesTruncated) {
            AMALogWarn(@"Error identifier truncated by %lu symbols", (unsigned long) newBytesTruncated);
            [self onTruncation:bytesTruncated bytesTruncated:newBytesTruncated];
        }];
    NSString *truncatedMessage =
        [self.messageTruncator truncatedString:details.message onTruncation:^(NSUInteger newBytesTruncated) {
            AMALogWarn(@"Error message truncated by %lu symbols", (unsigned long) newBytesTruncated);
            [self onTruncation:bytesTruncated bytesTruncated:newBytesTruncated];
    }];
    NSString *truncatedExceptionClass =
        [self.shortStringTruncator truncatedString:details.exceptionClass onTruncation:^(NSUInteger newBytesTruncated) {
            AMALogWarn(@"Exception class truncated by %lu symbols", (unsigned long) newBytesTruncated);
            [self onTruncation:bytesTruncated bytesTruncated:newBytesTruncated];
        }];

    AMAErrorCustomData *customError = [[AMAErrorCustomData alloc] initWithIdentifier:truncatedIdentifier
                                                                             message:truncatedMessage
                                                                           className:truncatedExceptionClass];
    NSUInteger totalBytesTruncated = bytesTruncated == NULL ? 0 : *bytesTruncated;
    AMALogInfo(@"Total bytes truncated: %lu", (unsigned long) totalBytesTruncated);
    AMAErrorModel *errorModel = [[AMAErrorModel alloc] initWithType:AMAErrorModelTypeVirtualMachineCustom
                                                         customData:customError
                                                        nsErrorData:nil
                                                   parametersString:nil
                                                reportCallBacktrace:nil
                                              userProvidedBacktrace:nil
                                                virtualMachineError:nil
                                                    underlyingError:nil
                                                     bytesTruncated:totalBytesTruncated];
    return errorModel;
}

- (AMAErrorModel *)modelForErrorRepresentable:(id<AMAErrorRepresentable>)error
                                      options:(AMAErrorReportingOptions)options
{
    return [self modelForErrorRepresentable:error options:options index:0];
}

- (AMAErrorModel *)modelForErrorRepresentable:(id<AMAErrorRepresentable>)error
                                      options:(AMAErrorReportingOptions)options
                                        index:(NSUInteger)index
{
    if (error == nil) {
        return nil;
    }
    if (index == self.maxUnderlyingErrorsCount) {
        AMALogWarn(@"Underlying errors count reached");
        return nil;
    }

    NSUInteger __block globalBytesTruncated = 0;
    NSString *identifier =
        [self.identifierTruncator truncatedString:error.identifier onTruncation:^(NSUInteger bytesTruncated) {
            AMALogWarn(@"Error identifier truncated");
            globalBytesTruncated += bytesTruncated;
        }];
    NSString *message = nil;
    if ([error respondsToSelector:@selector(message)]) {
        message = [self.messageTruncator truncatedString:error.message onTruncation:^(NSUInteger bytesTruncated) {
            AMALogWarn(@"Error message truncated");
            globalBytesTruncated += bytesTruncated;
        }];
    }
    NSString *className = NSStringFromClass(error.class);
    AMAErrorCustomData *data = [[AMAErrorCustomData alloc] initWithIdentifier:identifier
                                                                      message:message
                                                                    className:className];

    NSString *parametersString = nil;
    if ([error respondsToSelector:@selector(parameters)]) {
        parametersString = [self parametersStringForDictionary:error.parameters bytesTruncated:&globalBytesTruncated];
    }
    NSArray *reportCallBacktrace = [self limitedBacktrace:[self reportCallBacktraceForOptions:options]
                                           bytesTruncated:&globalBytesTruncated];
    NSArray *userProvidedBacktrace = nil;
    if ([error respondsToSelector:@selector(backtrace)]) {
        userProvidedBacktrace = [self limitedBacktrace:[self validatedBacktrace:error.backtrace]
                                        bytesTruncated:&globalBytesTruncated];
    }
    AMAErrorModel *underlyingError = nil;
    if ([error respondsToSelector:@selector(underlyingError)]) {
        underlyingError = [self modelForErrorRepresentable:error.underlyingError
                                                   options:options | AMAErrorReportingOptionsNoBacktrace
                                                     index:index + 1];
    }

    return [[AMAErrorModel alloc] initWithType:AMAErrorModelTypeCustom
                                    customData:data
                                   nsErrorData:nil
                              parametersString:parametersString
                           reportCallBacktrace:reportCallBacktrace
                         userProvidedBacktrace:userProvidedBacktrace
                           virtualMachineError:nil
                               underlyingError:underlyingError
                                bytesTruncated:globalBytesTruncated + underlyingError.bytesTruncated];
}

- (NSArray *)reportCallBacktraceForOptions:(AMAErrorReportingOptions)options
{
    if ((options & AMAErrorReportingOptionsNoBacktrace) != 0) {
        return nil;
    }
    NSMutableArray *backtrace = [NSThread.callStackReturnAddresses mutableCopy];

    // We remove this function call and the previous two(also happens here in this class)
    [backtrace removeObjectsInRange:NSMakeRange(0, 3)];

    return [backtrace copy];
}

- (NSArray *)validatedBacktrace:(NSArray *)backtrace
{
    if ([backtrace isKindOfClass:[NSArray class]] == NO) {
        AMALogWarn(@"Invalid backtrace class in NSError userInfo: %@", backtrace);
        return nil;
    }
    for (NSNumber *number in backtrace) {
        if ([number isKindOfClass:[NSNumber class]] == NO) {
            AMALogWarn(@"Invalid backtrace frame class in NSError userInfo: %@", backtrace);
            return nil;
        }
    }
    return backtrace;
}

- (NSArray *)limitedBacktrace:(NSArray *)backtrace bytesTruncated:(NSUInteger *)externalBytesTruncated
{
    if (backtrace.count <= self.maxBacktraceFramesCount) {
        return backtrace;
    }

    AMALogWarn(@"Error backtrace frames count limit reached");
    if (externalBytesTruncated != NULL) {
        *externalBytesTruncated += (backtrace.count - self.maxBacktraceFramesCount) * sizeof(uintptr_t);
    }
    return [backtrace subarrayWithRange:NSMakeRange(0, self.maxBacktraceFramesCount)];
}

- (NSString *)parametersStringForDictionary:(NSDictionary *)dictionary
                             bytesTruncated:(NSUInteger *)externalBytesTruncated
{
    NSDictionary *parameters = [self.environmentTruncator
        truncatedDictionary:dictionary
               onTruncation:^(NSUInteger bytesTruncated) {
                   [self onTruncation:externalBytesTruncated bytesTruncated:bytesTruncated];
               }];
    return [AMAJSONSerialization stringWithJSONObject:parameters error:nil];
}

- (void)onTruncation:(NSUInteger *)counter bytesTruncated:(NSUInteger)bytesTruncated
{
    if (counter != NULL) {
        *counter += bytesTruncated;
    }
}

@end
