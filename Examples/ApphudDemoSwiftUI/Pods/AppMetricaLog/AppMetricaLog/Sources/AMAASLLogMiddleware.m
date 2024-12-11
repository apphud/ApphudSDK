
#import "AMAASLLogMiddleware.h"
#import <asl.h>

#if !TARGET_OS_TV
static NSString *const kAMAASLLogMiddlewareDefaultFacility = @"io.appmetrica.log";
static const char* const kAMAASLKey = "AMALog";
static const char* const kAMAASLValue = "1";
#endif

@interface AMAASLLogMiddleware ()

@property (nonatomic, assign) asl_object_t logClient;
@property (nonatomic, copy) NSString *facility;

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
@implementation AMAASLLogMiddleware

- (BOOL)isAsyncLoggingAcceptable
{
    return YES;
}

#if TARGET_OS_TV

- (instancetype)initWithFacility:(NSString *)sender
{
    return [self init];
}

- (void)logMessage:(NSString *)message level:(AMALogLevel)level
{
}

#else

- (void)dealloc
{
    asl_close(_logClient);
}

- (instancetype)init
{
    return [self initWithFacility:kAMAASLLogMiddlewareDefaultFacility];
}

- (instancetype)initWithFacility:(NSString *)sender
{
    self = [super init];
    if (self != nil) {
        _logClient = asl_open(NULL, "com.apple.console", 0);
        _facility = [sender copy];
    }
    return self;
}

- (const char *)aslLogLevel:(AMALogLevel)logLevel
{
    switch (logLevel) {
        case AMALogLevelNone:
            return NULL;
        case AMALogLevelInfo:
            return "5"; // ASL_LEVEL_NOTICE
        case AMALogLevelWarning:
            return "4"; // ASL_LEVEL_WARNING
        case AMALogLevelError:
            return "3"; // ASL_LEVEL_ERR
        case AMALogLevelNotify:
            return "2"; // ASL_LEVEL_CRIT
    }
}

- (void)logMessage:(NSString *)message level:(AMALogLevel)level
{
    // This code could not be tested with unit tests anymore(https://nda.ya.ru/t/gtXlrhIO6fHaZi).
    // Be careful with editing it.

    if (message == nil) {
        return;
    }

    aslmsg m = asl_new(ASL_TYPE_MSG);
    if (m == NULL) {
        return;
    }

    const char *logLevel = [self aslLogLevel:level];
    BOOL canSendMessage = logLevel != NULL &&
                          asl_set(m, ASL_KEY_LEVEL, logLevel) == 0 &&
                          asl_set(m, ASL_KEY_MSG, [message UTF8String]) == 0 &&
                          asl_set(m, ASL_KEY_READ_UID, "-1") == 0 &&
                          asl_set(m, ASL_KEY_FACILITY, [self.facility UTF8String]) == 0 &&
                          asl_set(m, kAMAASLKey, kAMAASLValue) == 0;
    if (canSendMessage) {
        asl_send(self.logClient, m);
    }
    
    asl_free(m);
}

#endif

@end
#pragma clang diagnostic pop
