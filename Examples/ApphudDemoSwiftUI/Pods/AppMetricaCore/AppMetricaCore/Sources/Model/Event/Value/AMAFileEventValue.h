
#import <Foundation/Foundation.h>
#import "AMAEventValueProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface AMAFileEventValue : NSObject <AMAEventValueProtocol>

@property (nonatomic, assign, readonly) AMAEventEncryptionType encryptionType;
@property (nonatomic, copy, readonly) NSString *relativeFilePath;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithRelativeFilePath:(NSString *)relativeFilePath
                          encryptionType:(AMAEventEncryptionType)encryptionType;

@end

NS_ASSUME_NONNULL_END
