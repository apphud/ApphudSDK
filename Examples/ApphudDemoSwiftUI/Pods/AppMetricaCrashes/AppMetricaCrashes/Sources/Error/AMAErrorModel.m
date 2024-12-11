
#import "AMAErrorModel.h"
#import "AMAErrorCustomData.h"
#import "AMAErrorNSErrorData.h"

@implementation AMAErrorModel

- (instancetype)initWithType:(AMAErrorModelType)type
                  customData:(AMAErrorCustomData *)customData
                 nsErrorData:(AMAErrorNSErrorData *)nsErrorData
            parametersString:(NSString *)parametersString
         reportCallBacktrace:(NSArray<NSNumber *> *)reportCallBacktrace
       userProvidedBacktrace:(NSArray<NSNumber *> *)userProvidedBacktrace
         virtualMachineError:(AMAVirtualMachineError *)virtualMachineError
             underlyingError:(AMAErrorModel *)underlyingError
              bytesTruncated:(NSUInteger)bytesTruncated
{
    self = [super init];
    if (self != nil) {
        _type = type;
        _customData = customData;
        _nsErrorData = nsErrorData;
        _parametersString = [parametersString copy];
        _reportCallBacktrace = [reportCallBacktrace copy];
        _userProvidedBacktrace = [userProvidedBacktrace copy];
        _virtualMachineError = virtualMachineError;
        _underlyingError = underlyingError;
        _bytesTruncated = bytesTruncated;
    }
    return self;
}

- (NSString *)name
{
    if (self.customData != nil) {
        return self.customData.identifier;
    }
    if (self.nsErrorData != nil) {
        return [NSString stringWithFormat:@"Error Domain=%@ Code=%ld",
                self.nsErrorData.domain, (long)self.nsErrorData.code];
    }
    return @"Error";
}

@end
