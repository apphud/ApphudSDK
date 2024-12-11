
#import <Foundation/Foundation.h>
#import "AMAReporterDatabaseEncryptionType.h"

@protocol AMADataEncoding;

@interface AMAReporterDatabaseEncodersFactory : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (AMAReporterDatabaseEncryptionType)eventDataEncryptionType;
+ (AMAReporterDatabaseEncryptionType)sessionDataEncryptionType;

+ (id<AMADataEncoding>)encoderForEncryptionType:(AMAReporterDatabaseEncryptionType)encryptionType;

@end
