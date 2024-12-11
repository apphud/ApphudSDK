
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, AMAReporterDatabaseEncryptionType) {
    // AES-128 encryption without compression
    // The key is 8eed7f8d98844045933e986e412ae92b (hex), iv is md5(bundleID ?: "io.appmetrica.sdk")
    AMAReporterDatabaseEncryptionTypeAES = 0,

    // AES-128 encryption with GZip compression
    // The key is af9dca1be79a4197a04b42242850c6c2 (hex), iv is md5(bundleID ?: "io.appmetrica.sdk")
    AMAReporterDatabaseEncryptionTypeGZipAES = 1,
};
