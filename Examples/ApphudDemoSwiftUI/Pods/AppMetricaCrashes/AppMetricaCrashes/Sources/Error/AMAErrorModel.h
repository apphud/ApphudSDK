
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, AMAErrorModelType) {
    AMAErrorModelTypeCustom,
    AMAErrorModelTypeNSError,
    AMAErrorModelTypeVirtualMachine,
    AMAErrorModelTypeVirtualMachineCustom,
};

@class AMAErrorCustomData;
@class AMAErrorNSErrorData;
@class AMAVirtualMachineError;

@interface AMAErrorModel : NSObject

@property (nonatomic, assign, readonly) AMAErrorModelType type;

@property (nonatomic, strong, readonly) AMAErrorCustomData *customData;
@property (nonatomic, strong, readonly) AMAErrorNSErrorData *nsErrorData;

@property (nonatomic, copy, readonly) NSString *parametersString;

@property (nonatomic, copy, readonly) NSArray<NSNumber *> *reportCallBacktrace;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *userProvidedBacktrace;

@property (nonatomic, strong, readonly) AMAErrorModel *underlyingError;

@property (nonatomic, assign, readonly) NSUInteger bytesTruncated;
@property (nonatomic, strong, readonly) AMAVirtualMachineError *virtualMachineError;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithType:(AMAErrorModelType)type
                  customData:(AMAErrorCustomData *)customData
                 nsErrorData:(AMAErrorNSErrorData *)nsErrorData
            parametersString:(NSString *)parametersString
         reportCallBacktrace:(NSArray<NSNumber *> *)reportCallBacktrace
       userProvidedBacktrace:(NSArray<NSNumber *> *)userProvidedBacktrace
         virtualMachineError:(AMAVirtualMachineError *)virtualMachineError
             underlyingError:(AMAErrorModel *)underlyingError
              bytesTruncated:(NSUInteger)bytesTruncated;

- (NSString *)name;

@end
