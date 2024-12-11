
#import <Foundation/Foundation.h>

NS_SWIFT_NAME(ExtendedCrashProcessing)
@protocol AMAExtendedCrashProcessing <NSObject>

- (void)processError:(NSError *)error;

@end
