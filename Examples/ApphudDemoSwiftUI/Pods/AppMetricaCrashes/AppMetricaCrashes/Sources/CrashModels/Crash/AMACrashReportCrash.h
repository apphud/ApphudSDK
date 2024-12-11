
#import <Foundation/Foundation.h>

@class AMACrashReportError;
@class AMAThread;

@interface AMACrashReportCrash : NSObject <NSCopying>

@property (nonatomic, strong, readonly) AMACrashReportError *error;
@property (nonatomic, copy, readonly) NSArray<AMAThread *> *threads;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithError:(AMACrashReportError *)error threads:(NSArray<AMAThread *> *)threads;

@end

