
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AMADatabaseKeyValueStorageProviding;
@protocol AMADateProviding;
@class AMAIncrementableValueStorage;
@class AMAEnvironmentContainer;
@class AMAExtrasContainer;

@interface AMAReporterStateStorage : NSObject

@property (nonatomic, assign, readonly) BOOL firstEventSent;
@property (nonatomic, assign, readonly) BOOL initEventSent;
@property (nonatomic, assign, readonly) BOOL updateEventSent;
@property (nonatomic, assign, readonly) BOOL referrerEventSent
    __attribute__((deprecated("Used only for migration to version 19")));
@property (nonatomic, assign, readonly) BOOL emptyReferrerEventSent
    __attribute__((deprecated("Used only for migration to version 19")));

@property (nonatomic, strong, readonly) AMAIncrementableValueStorage *sessionIDStorage;
@property (nonatomic, strong, readonly) AMAIncrementableValueStorage *attributionIDStorage;
@property (nonatomic, strong, readonly) AMAIncrementableValueStorage *requestIDStorage;

@property (nonatomic, strong, readonly) AMAEnvironmentContainer *appEnvironment;
@property (nonatomic, strong, readonly) AMAEnvironmentContainer *eventEnvironment;
@property (nullable, nonatomic, strong, readonly) AMAExtrasContainer *extrasContainer;

@property (nonatomic, copy, nullable) NSString *profileID;
@property (nonatomic, assign, readonly) NSUInteger openID;

@property (nonatomic, strong, readonly) NSDate *lastStateSendDate;

@property (nonatomic, strong, readonly) NSDate *lastASATokenSendDate;

@property (atomic, strong, readonly) NSDate *privacyLastSendDate;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithStorageProvider:(id<AMADatabaseKeyValueStorageProviding>)storageProvider
                       eventEnvironment:(AMAEnvironmentContainer *)eventEnvironment;
- (instancetype)initWithStorageProvider:(id<AMADatabaseKeyValueStorageProviding>)storageProvider
                       eventEnvironment:(AMAEnvironmentContainer *)eventEnvironment
                           dateProvider:(id<AMADateProviding>)dateProvider;

- (void)restoreState;

- (void)markFirstEventSent;
- (void)markInitEventSent;
- (void)markUpdateEventSent;
- (void)markReferrerEventSent __attribute__((deprecated("Used only for migration to version 19")));
- (void)markEmptyReferrerEventSent __attribute__((deprecated("Used only for migration to version 19")));

- (void)markStateSentNow;

- (void)markASATokenSentNow;
- (void)incrementOpenID;

- (void)markLastPrivacySentNow;

@end

NS_ASSUME_NONNULL_END
