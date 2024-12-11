
#import "AMAStartupClientIdentifier.h"

NSString *const kAMAStartupParameterDeviceID = @"deviceid";
NSString *const kAMAStartupParameterDeviceIDHash = @"deviceidhash";
NSString *const kAMAStartupParameterUUID = @"uuid";
NSString *const kAMAStartupParameterDeviceIDForVendor = @"ifv";

static NSString *const kAMADeviceIDDefaultValue = @"";
static NSString *const kAMADeviceIDHashDefaultValue = @"";
static NSString *const kAMAIFVDefaultValue = @"";

@implementation AMAStartupClientIdentifier

- (NSDictionary<NSString *, id> *)startupParameters
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    dictionary[kAMAStartupParameterDeviceID] = self.deviceID.length > 0 ? self.deviceID : kAMADeviceIDDefaultValue;
    dictionary[kAMAStartupParameterDeviceIDHash] = self.deviceIDHash.length > 0 ? self.deviceIDHash : kAMADeviceIDHashDefaultValue;
    dictionary[kAMAStartupParameterUUID] = self.UUID.length > 0 ? self.UUID : nil;
    dictionary[kAMAStartupParameterDeviceIDForVendor] = self.IFV.length > 0 ? self.IFV : kAMAIFVDefaultValue;
    
    if (self.otherParameters != nil) {
        [dictionary addEntriesFromDictionary:self.otherParameters];
    }
    return [dictionary copy];
}

@end
