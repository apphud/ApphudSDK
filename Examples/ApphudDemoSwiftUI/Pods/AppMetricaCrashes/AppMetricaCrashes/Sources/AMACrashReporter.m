
#import "AMACrashLogging.h"
#import "AMACrashReporter.h"
#import <AppMetricaCoreExtension/AppMetricaCoreExtension.h>
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import "AMAErrorModel.h"
#import "AMAExceptionFormatter.h"
#import "AMACrashEventType.h"
#import "AMAErrorModelFactory.h"
#import "AMAPluginErrorDetails.h"
#import "AMAErrorEnvironment.h"

static NSString *const kAppMetricaLibraryAPIKey = @"20799a27-fa80-4b36-b2db-0f8141f24180";

@interface AMACrashReporter ()

@property (nonatomic, strong, readonly) id<AMAAppMetricaReporting> libraryErrorReporter;
@property (nonatomic, strong, readonly) id<AMAExceptionFormatting> exceptionFormatter;
@property (nonatomic, strong, readonly) AMAErrorModelFactory *errorModelFactory;
@property (nonatomic, copy, readonly) NSString *apiKey;

@property (nonatomic, strong) AMAErrorEnvironment *errorEnvironment;

@end

@implementation AMACrashReporter

- (instancetype)initWithApiKey:(NSString *)apiKey
{
    return [self initWithApiKey:apiKey errorEnvironment:[[AMAErrorEnvironment alloc] init]];
}

- (instancetype)initWithApiKey:(NSString *)apiKey errorEnvironment:(AMAErrorEnvironment *)errorEnvironment
{
    self = [super init];
    if (self != nil) {
        _apiKey = apiKey;
        _libraryErrorReporter = [AMAAppMetrica reporterForAPIKey:kAppMetricaLibraryAPIKey];
        _exceptionFormatter = [[AMAExceptionFormatter alloc] init];
        _errorEnvironment = errorEnvironment;
        _errorModelFactory = [AMAErrorModelFactory sharedInstance];
    }
    return self;
}

#pragma mark - AMAAppMetricaCrashReporting -

- (void)setErrorEnvironmentValue:(NSString *)value forKey:(NSString *)key
{
    [self.errorEnvironment addValue:value forKey:key];
}

- (void)clearErrorEnvironment
{
    [self.errorEnvironment clearEnvironment];
}

- (void)reportNSError:(NSError *)error onFailure:(void (^)(NSError *))onFailure
{
    [self reportNSError:error options:0 onFailure:onFailure];
}

- (void)reportNSError:(NSError *)error 
              options:(AMAErrorReportingOptions)options
            onFailure:(void (^)(NSError *))onFailure
{
    [self reportErrorModel:[self.errorModelFactory modelForNSError:error options:options]
                 onFailure:onFailure];
}

- (void)reportError:(id<AMAErrorRepresentable>)error onFailure:(void (^)(NSError *))onFailure
{
    [self reportError:error options:0 onFailure:onFailure];
}

- (void)reportError:(id<AMAErrorRepresentable>)error 
            options:(AMAErrorReportingOptions)options
          onFailure:(void (^)(NSError *))onFailure
{
    [self reportErrorModel:[self.errorModelFactory modelForErrorRepresentable:error options:options]
                 onFailure:onFailure];
}

- (id<AMAAppMetricaPluginReporting>)pluginExtension
{
    return self;
}

#pragma mark - AMAAppMetricaPluginReporting -

- (void)reportUnhandledException:(AMAPluginErrorDetails *)errorDetails onFailure:(void (^)(NSError *))onFailure
{
    NSError *potentialError = nil;
    NSUInteger bytesTruncated = 0;
    NSData *formattedData = [self.exceptionFormatter formattedCrashErrorDetails:errorDetails
                                                                 bytesTruncated:&bytesTruncated
                                                                          error:&potentialError];

    if (formattedData == nil) {
        [self reportInternalCorruptedError:potentialError];
        onFailure(potentialError);
        return;
    }
    
    id<AMAAppMetricaExtendedReporting> reporter = [AMAAppMetrica extendedReporterForApiKey:self.apiKey];
    
    [reporter reportBinaryEventWithType:AMACrashEventTypeCrash
                                   data:formattedData
                                   name:errorDetails.exceptionClass
                                gZipped:YES
                       eventEnvironment:self.errorEnvironment.currentEnvironment
                         appEnvironment:nil
                                 extras:nil
                         bytesTruncated:bytesTruncated
                              onFailure:onFailure];
}

- (void)reportError:(AMAPluginErrorDetails *)errorDetails
            message:(NSString *)message
          onFailure:(void (^)(NSError *))onFailure
{
    NSError *potentialError = nil;

    // TODO: https://nda.ya.ru/t/L9eD2ClO74ZR6E
    NSError *badBacktraceError = [AMAErrorUtilities errorWithCode:AMAAppMetricaEventErrorCodeInvalidBacktrace
                                                      description:@"Backtrace is null or empty"];
    
    if (errorDetails == nil || errorDetails.backtrace.count == 0) {
        [AMAErrorUtilities fillError:&potentialError withError:badBacktraceError];
        [AMAFailureDispatcher dispatchError:potentialError withBlock:onFailure];
        return;
    }
    
    NSUInteger bytesTruncated = 0;
    NSData *formattedData = [self.exceptionFormatter formattedErrorErrorDetails:errorDetails
                                                                 bytesTruncated:&bytesTruncated
                                                                          error:&potentialError];
    
    if (formattedData == nil) {
        [self reportInternalCorruptedError:potentialError];
        onFailure(potentialError);
        return;
    }
    
    id<AMAAppMetricaExtendedReporting> reporter = [AMAAppMetrica extendedReporterForApiKey:self.apiKey];
    
    [reporter reportBinaryEventWithType:AMACrashEventTypeError
                                   data:formattedData
                                   name:message
                                gZipped:YES
                       eventEnvironment:self.errorEnvironment.currentEnvironment
                         appEnvironment:nil
                                 extras:nil
                         bytesTruncated:bytesTruncated
                              onFailure:onFailure];
}

- (void)reportErrorWithIdentifier:(NSString *)identifier
                          message:(NSString *)message
                          details:(AMAPluginErrorDetails *)errorDetails
                        onFailure:(void (^)(NSError *))onFailure
{
    NSError *potentialError = nil;
    
    // TODO: https://nda.ya.ru/t/L9eD2ClO74ZR6E
    NSString *errorMsg = [NSString stringWithFormat:@"Identifier '%@' is incorrect", identifier];
    NSError *badIdentifierError = [AMAErrorUtilities errorWithCode:AMAAppMetricaEventErrorCodeInvalidName
                                                       description:errorMsg];
    
    if (identifier.length == 0) {
        [AMAErrorUtilities fillError:&potentialError withError:badIdentifierError];
        [AMAFailureDispatcher dispatchError:potentialError withBlock:onFailure];
        return;
    }
    
    NSUInteger bytesTruncated = 0;
    NSData *formattedData = [self.exceptionFormatter formattedCustomErrorErrorDetails:errorDetails
                                                                           identifier:identifier
                                                                       bytesTruncated:&bytesTruncated
                                                                                error:&potentialError];
    
    if (formattedData == nil) {
        [self reportInternalCorruptedError:potentialError];
        onFailure(potentialError);
        return;
    }
    
    id<AMAAppMetricaExtendedReporting> reporter = [AMAAppMetrica extendedReporterForApiKey:self.apiKey];
    
    [reporter reportBinaryEventWithType:AMACrashEventTypeError
                                   data:formattedData
                                   name:message
                                gZipped:YES
                       eventEnvironment:self.errorEnvironment.currentEnvironment
                         appEnvironment:nil
                                 extras:nil
                         bytesTruncated:bytesTruncated
                              onFailure:onFailure];
}

#pragma mark - Public -
// FIXME: Inconsistent code, required refactoring
- (void)reportCrashWithParameters:(nonnull AMAEventPollingParameters *)parameters
{
    id<AMAAppMetricaExtendedReporting> reporter = [AMAAppMetrica extendedReporterForApiKey:self.apiKey];
    
    [reporter reportFileEventWithType:AMACrashEventTypeCrash
                                 data:parameters.data
                             fileName:parameters.fileName
                              gZipped:YES
                            encrypted:NO
                            truncated:NO
                     eventEnvironment:parameters.eventEnvironment
                       appEnvironment:parameters.appEnvironment
                               extras:parameters.extras
                            onFailure:^(NSError *error) {
        if (error != nil) {
            AMALogError(@"Failed to report app crash with error: %@", error);
            [self reportErrorToAppMetricaWithError:error eventName:@"internal_error_crash"];
        }
    }];
}

- (void)reportANRWithParameters:(nonnull AMAEventPollingParameters *)parameters
{
    id<AMAAppMetricaExtendedReporting> reporter = [AMAAppMetrica extendedReporterForApiKey:self.apiKey];
    
    [reporter reportFileEventWithType:AMACrashEventTypeANR
                                 data:parameters.data
                             fileName:parameters.fileName
                              gZipped:YES
                            encrypted:NO
                            truncated:NO
                     eventEnvironment:parameters.eventEnvironment
                       appEnvironment:parameters.appEnvironment
                               extras:parameters.extras
                            onFailure:^(NSError *error) {
        if (error != nil) {
            AMALogError(@"Failed to report app crash with error: %@", error);
            [self reportErrorToAppMetricaWithError:error eventName:@"internal_error_anr"];
        }
    }];
}

- (void)reportInternalError:(NSError *)error
{
    NSString *eventName;
    
    switch (error.code) {
        case AMAAppMetricaEventErrorCodeInvalidName:
            eventName = @"corrupted_crash_report_invalid_name";
            break;
        case AMAAppMetricaInternalEventErrorCodeRecrash:
            eventName = @"crash_report_recrash";
            break;
        case AMAAppMetricaInternalEventErrorCodeUnsupportedReportVersion:
            eventName = @"crash_report_version_unsupported";
            break;
        default:
            return;
    }
    
    [self reportErrorToAppMetricaWithError:error eventName:eventName];
}

- (void)reportInternalCorruptedCrash:(NSError *)error
{
    [self reportErrorToAppMetricaWithError:error eventName:@"corrupted_crash_report"];
}

- (void)reportInternalCorruptedError:(NSError *)error
{
    [self reportErrorToAppMetricaWithError:error eventName:@"corrupted_error_report"];
}

#pragma mark - Private -

- (void)reportErrorModel:(AMAErrorModel *)error onFailure:(void (^)(NSError *error))onFailure
{
    NSError *potentialError = nil;
    NSData *formattedData = [self.exceptionFormatter formattedError:error error:&potentialError];
    
    if (formattedData == nil) {
        [self reportInternalCorruptedError:potentialError];
        onFailure(potentialError);
        return;
    }
    
    id<AMAAppMetricaExtendedReporting> reporter = [AMAAppMetrica extendedReporterForApiKey:self.apiKey];
    
    [reporter reportBinaryEventWithType:AMACrashEventTypeError
                                   data:formattedData
                                   name:nil
                                gZipped:YES
                       eventEnvironment:self.errorEnvironment.currentEnvironment
                         appEnvironment:nil
                                 extras:nil
                         bytesTruncated:0
                              onFailure:onFailure];
}

- (void)reportErrorToAppMetricaWithError:(NSError *)error eventName:(NSString *)eventName
{
    NSDictionary *parameters = @{
        @"domain" : error.domain ?: @"<unknown>",
        @"error_code" : @(error.code),
        @"error_details" : error.userInfo.count > 0 ? error.userInfo.description : @"No error details supplied",
    };
    
    [self.libraryErrorReporter reportEvent:eventName parameters:parameters onFailure:nil];
}

- (NSDictionary *)descriptionParametersForException:(NSException *)exception
{
    if (exception == nil) {
        return nil;
    }

    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[@"name"] = exception.name;
    parameters[@"reason"] = exception.reason;
    parameters[@"backtrace"] = exception.callStackSymbols;
    parameters[@"userInfo"] = exception.userInfo;

    return [parameters copy];
}

#pragma mark - AMATransactionReporter

- (void)reportFailedTransactionWithID:(NSString *)transactionID
                            ownerName:(NSString *)ownerName
                      rollbackContent:(NSString *)rollbackContent
                    rollbackException:(NSException *)rollbackException
                       rollbackFailed:(BOOL)rollbackFailed
{
    NSString *parametersKey = transactionID ?: @"Unknown";
    NSDictionary *exceptionParameters = [self descriptionParametersForException:rollbackException];

    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    parameters[@"name"] = ownerName;
    parameters[@"exception"] = exceptionParameters;
    parameters[@"rollbackcontent"] = rollbackContent;
    parameters[@"rollback"] = rollbackFailed ? @"failed" : @"succeeded";

    [self.libraryErrorReporter reportEvent:@"TransactionFailure"
                                parameters:@{ parametersKey: [parameters copy] }
                                 onFailure:nil];
}

@end
