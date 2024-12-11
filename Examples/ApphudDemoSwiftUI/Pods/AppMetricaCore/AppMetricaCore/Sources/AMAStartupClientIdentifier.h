
#import <Foundation/Foundation.h>

extern NSString *const kAMAStartupParameterDeviceID;
extern NSString *const kAMAStartupParameterDeviceIDHash;
extern NSString *const kAMAStartupParameterUUID;
extern NSString *const kAMAStartupParameterDeviceIDForVendor;

@interface AMAStartupClientIdentifier : NSObject

@property (nonatomic, copy) NSString *deviceID;
@property (nonatomic, copy) NSString *deviceIDHash;
@property (nonatomic, copy) NSString *UUID;
@property (nonatomic, copy) NSString *IFV;

@property (nonatomic, copy) NSDictionary *otherParameters;

- (NSDictionary<NSString *, id> *)startupParameters;

@end
