
#import <Foundation/Foundation.h>
#import "AMAReporterDatabaseEncodersFactory.h"

@interface AMAReporterDatabaseEncodersFactory (Migration)

+ (id<AMADataEncoding>)migrationEncoderForEncryptionType:(AMAReporterDatabaseEncryptionType)encryptionType;

@end
