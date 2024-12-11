
#import <Foundation/Foundation.h>
#import "AMAEventEncryptionType.h"

@protocol AMAFileStorage;

@interface AMAEncryptedFileStorageFactory : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (id<AMAFileStorage>)fileStorageForEncryptionType:(AMAEventEncryptionType)encryptionType filePath:(NSString *)filePath;

@end
