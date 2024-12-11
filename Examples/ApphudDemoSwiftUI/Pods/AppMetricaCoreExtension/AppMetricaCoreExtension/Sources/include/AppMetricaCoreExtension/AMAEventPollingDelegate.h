
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class AMAApplicationState;

NS_SWIFT_NAME(AMAEventPollingParameters)
@interface AMAEventPollingParameters : NSObject

@property (nonatomic) NSUInteger eventType;
@property (nonatomic, nullable) NSData *data;
/// If creationDate is nil, current date is used
@property (nonatomic, nullable) NSDate *creationDate;
@property (nonatomic, nullable) NSString *fileName;
@property (nonatomic, copy, nullable) NSDictionary *appEnvironment;
@property (nonatomic, copy, nullable) NSDictionary *eventEnvironment;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSData *> *extras;
/// Takes effect in session fetching if the event is in the past
@property (nonatomic, nullable) AMAApplicationState *appState;
/// In case you use some kind of own truncator. The value will be added to truncated bytes number inside. Defaut is 0.
@property (nonatomic, assign) NSUInteger bytesTruncated;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithEventType:(NSUInteger)eventType;

@end

NS_SWIFT_NAME(EventFlushableDelegate)
@protocol AMAEventPollingDelegate <NSObject>

+ (NSArray<AMAEventPollingParameters *> *)eventsForPreviousSession;

+ (void)setupAppEnvironment:(AMAEnvironmentContainer *)appEnvironment;

@end

NS_ASSUME_NONNULL_END
