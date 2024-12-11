
#import <Foundation/Foundation.h>

NS_SWIFT_NAME(FileStorage)
@protocol AMAFileStorage <NSObject>

@property (nonatomic, assign, readonly) BOOL fileExists;

- (NSData *)readDataWithError:(NSError **)error;
- (BOOL)writeData:(NSData *)data error:(NSError **)error;
- (BOOL)deleteFileWithError:(NSError **)error;

@end
