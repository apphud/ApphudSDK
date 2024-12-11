
#import <Foundation/Foundation.h>

@class AMAStartupParametersConfiguration;
@class AMAAttributionModelConfiguration;

@interface AMAStartupResponse : NSObject

@property (nonatomic, strong, readonly) AMAStartupParametersConfiguration *configuration;

@property (nonatomic, copy) NSString *deviceID;
@property (nonatomic, copy) NSString *deviceIDHash;
@property (nonatomic, strong) AMAAttributionModelConfiguration *attributionModelConfiguration;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithStartupConfiguration:(AMAStartupParametersConfiguration *)configuration;

@end
