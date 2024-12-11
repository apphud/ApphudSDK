
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AMAKeyValueStorageProviding;
@protocol AMAKeyValueStoring;

NS_SWIFT_NAME(ReporterStorageControlling)
@protocol AMAReporterStorageControlling <NSObject>

- (void)setupWithReporterStorage:(id<AMAKeyValueStorageProviding>)stateStorageProvider
                            main:(BOOL)main
                       forAPIKey:(NSString *)apiKey;

@end

NS_ASSUME_NONNULL_END
