
#import <Foundation/Foundation.h>

@protocol AMADatabaseKeyValueStorageProviding;
@protocol AMAKeyValueStoring;
@protocol AMADatabaseProtocol;
@class AMAReporterStateStorage;
@class AMASessionStorage;
@class AMAEventStorage;
@class AMAReportRequestProvider;
@class AMAEventsCleaner;
@class AMASessionsCleaner;
@class AMAEnvironmentContainer;
@class AMAEvent;
@class AMASession;

NS_ASSUME_NONNULL_BEGIN

@interface AMAReporterStorage : NSObject

@property (nonatomic, copy, readonly) NSString *apiKey;
@property (nonatomic, strong, readonly) id<AMADatabaseKeyValueStorageProviding> keyValueStorageProvider;
@property (nonatomic, strong, readonly) AMAReporterStateStorage *stateStorage;
@property (nonatomic, strong, readonly) AMASessionStorage *sessionStorage;
@property (nonatomic, strong, readonly) AMAEventStorage *eventStorage;
@property (nonatomic, strong, readonly) AMAReportRequestProvider *reportRequestProvider;
@property (nonatomic, strong, readonly) AMASessionsCleaner *sessionsCleaner;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithApiKey:(NSString *)apiKey
              eventEnvironment:(AMAEnvironmentContainer *)eventEnvironment
                          main:(BOOL)main;
- (instancetype)initWithApiKey:(NSString *)apiKey
              eventEnvironment:(AMAEnvironmentContainer *)eventEnvironment
                 eventsCleaner:(AMAEventsCleaner *)eventsCleaner
                      database:(id<AMADatabaseProtocol>)database
                          main:(BOOL)main;

- (void)storageInDatabase:(void (^)(id<AMAKeyValueStoring> storage))block;

- (void)restoreState;

- (void)updateAPIKey:(NSString *)apiKey;

@end

NS_ASSUME_NONNULL_END
