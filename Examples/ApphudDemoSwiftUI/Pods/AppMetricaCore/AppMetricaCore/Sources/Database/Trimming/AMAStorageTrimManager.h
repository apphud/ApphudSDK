
#import <Foundation/Foundation.h>

@class AMANotificationsListener;
@class AMAEventsCleaner;
@protocol AMADatabaseProtocol;

@interface AMAStorageTrimManager : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithApiKey:(NSString *)apiKey
                 eventsCleaner:(AMAEventsCleaner *)eventsCleaner;
- (instancetype)initWithApiKey:(NSString *)apiKey
                 eventsCleaner:(AMAEventsCleaner *)eventsCleaner
         notificationsListener:(AMANotificationsListener *)listener;

- (void)subscribeDatabase:(id<AMADatabaseProtocol>)database;
- (void)unsubscribeDatabase:(id<AMADatabaseProtocol>)database;

@end
