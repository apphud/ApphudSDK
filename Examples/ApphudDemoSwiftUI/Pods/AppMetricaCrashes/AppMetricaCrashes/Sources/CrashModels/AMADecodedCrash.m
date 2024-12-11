#import "AMADecodedCrash.h"
#import "AMAInfo.h"
#import "AMABacktrace.h"
#import "AMACrashReportCrash.h"
#import "AMAThread.h"
#import "AMACrashLogging.h"
#import "AMABuildUID.h"
#import <AppMetricaPlatform/AppMetricaPlatform.h>

@implementation AMADecodedCrash

- (instancetype)initWithAppState:(AMAApplicationState *)appState
                     appBuildUID:(AMABuildUID *)appBuildUID
                errorEnvironment:(NSDictionary *)errorEnvironment
                  appEnvironment:(NSDictionary *)appEnvironment
                            info:(AMAInfo *)info
                    binaryImages:(NSArray<AMABinaryImage *> *)binaryImages
                          system:(AMASystem *)system
                           crash:(AMACrashReportCrash *)crash
{
    self = [super init];
    if (self != nil) {
        _appState = [appState copy];
        _appBuildUID = [appBuildUID copy];
        _errorEnvironment = [errorEnvironment copy];
        _appEnvironment = [appEnvironment copy];
        _info = info;
        _binaryImages = [binaryImages copy];
        _system = system;
        _crash = crash;
    }

    return self;
}

+ (instancetype)crashWithAppState:(AMAApplicationState *)appState
                      appBuildUID:(AMABuildUID *)appBuildUID
                 errorEnvironment:(NSDictionary *)errorEnvironment
                   appEnvironment:(NSDictionary *)appEnvironment
                             info:(AMAInfo *)info
                     binaryImages:(NSArray<AMABinaryImage *> *)binaryImages
                           system:(AMASystem *)system
                            crash:(AMACrashReportCrash *)crash
{
    return [[self alloc] initWithAppState:appState
                              appBuildUID:appBuildUID
                         errorEnvironment:errorEnvironment
                           appEnvironment:appEnvironment
                                     info:info
                             binaryImages:binaryImages
                                   system:system
                                    crash:crash];
}

- (AMABacktrace *)crashedThreadBacktrace
{
    NSUInteger index =
        [self.crash.threads indexOfObjectPassingTest:^BOOL(AMAThread *obj, NSUInteger idx, BOOL *stop) {
            return obj.crashed;
        }];

    AMABacktrace *backtrace = nil;
    if (index != NSNotFound) {
        backtrace = self.crash.threads[index].backtrace;
    }
    return backtrace;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] alloc] initWithAppState:self.appState
                                      appBuildUID:self.appBuildUID
                                 errorEnvironment:self.errorEnvironment
                                   appEnvironment:self.appEnvironment
                                             info:self.info
                                     binaryImages:self.binaryImages
                                           system:self.system
                                            crash:[self.crash copy]];
}

@end
