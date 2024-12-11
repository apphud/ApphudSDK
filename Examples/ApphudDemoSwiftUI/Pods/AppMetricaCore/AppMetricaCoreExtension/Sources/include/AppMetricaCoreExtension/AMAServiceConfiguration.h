
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AMAExtendedStartupObserving;
@protocol AMAReporterStorageControlling;

NS_SWIFT_NAME(ServiceConfiguration)
@interface AMAServiceConfiguration : NSObject

@property (nonatomic, nullable, strong, readonly) id<AMAExtendedStartupObserving> startupObserver;
@property (nonatomic, nullable, strong, readonly) id<AMAReporterStorageControlling> reporterStorageController;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithStartupObserver:(nullable id<AMAExtendedStartupObserving>)startupObserver
              reporterStorageController:(nullable id<AMAReporterStorageControlling>)reporterStorageController;

@end

NS_ASSUME_NONNULL_END
