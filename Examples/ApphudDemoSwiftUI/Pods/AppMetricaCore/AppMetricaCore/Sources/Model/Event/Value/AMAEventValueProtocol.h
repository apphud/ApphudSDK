
#import <Foundation/Foundation.h>
#import "AMAEventEncryptionType.h"

@protocol AMAEventValueProtocol <NSObject>

@property (nonatomic, assign, readonly) AMAEventEncryptionType encryptionType;
@property (nonatomic, assign, readonly) BOOL empty;

- (NSData *)dataWithError:(NSError **)error;

@optional

- (NSData *)gzippedDataWithError:(NSError **)error;
- (void)cleanup;

@end
