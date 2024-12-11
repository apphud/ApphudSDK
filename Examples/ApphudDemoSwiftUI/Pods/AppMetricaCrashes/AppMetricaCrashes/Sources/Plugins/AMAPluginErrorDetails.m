
#import "AMAPluginErrorDetails.h"
#import "AMAStackTraceElement.h"

@implementation AMAPluginErrorDetails

NSString * const kAMAPlatformNative = @"native";
NSString * const kAMAPlatformFlutter = @"flutter";
NSString * const kAMAPlatformUnity = @"unity";
NSString * const kAMAPlatformReactNative = @"react_native";
NSString * const kAMAPlatformXamarin = @"xamarin";
NSString * const kAMAPlatformCordova = @"cordova";

- (instancetype)init
{
    return [self initWithExceptionClass:nil
                                message:nil
                              backtrace:nil
                               platform:nil
                  virtualMachineVersion:nil
                      pluginEnvironment:nil];
}

- (instancetype)initWithExceptionClass:(nullable NSString *)exceptionClass
                               message:(nullable NSString *)message
                             backtrace:(nullable NSArray<AMAStackTraceElement *> *)backtrace
                              platform:(nullable NSString *)platform
                 virtualMachineVersion:(nullable NSString *)virtualMachineVersion
                     pluginEnvironment:(nullable NSDictionary<NSString *, NSString *> *)pluginEnvironment
{
    self = [super init];
    if (self != nil) {
        _exceptionClass = [exceptionClass copy];
        _message = [message copy];
        _backtrace = [backtrace copy];
        _platform = [platform copy];
        _virtualMachineVersion = [virtualMachineVersion copy];
        _pluginEnvironment = [pluginEnvironment copy];
    }
    return self;
}

@end
