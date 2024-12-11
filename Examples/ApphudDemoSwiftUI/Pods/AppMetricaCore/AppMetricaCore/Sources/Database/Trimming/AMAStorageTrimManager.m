
#import "AMAStorageTrimManager.h"
#import "AMANotificationsListener.h"
#import "AMADatabaseProtocol.h"
#import "AMAStorageTrimming.h"
#import "AMAStorageEventsTrimTransaction.h"
#import "AMAPlainStorageTrimmer.h"
#import "AMAReporterNotifications.h"
#import "AMAEventsCountStorageTrimmer.h"
#import <UIKit/UIKit.h>

@interface AMAStorageTrimManager ()

@property (nonatomic, copy, readonly) NSString *apiKey;
@property (nonatomic, strong, readonly) AMAEventsCleaner *eventsCleaner;
@property (nonatomic, strong, readonly) AMANotificationsListener *listener;

@end

@implementation AMAStorageTrimManager

- (instancetype)initWithApiKey:(NSString *)apiKey
                 eventsCleaner:(AMAEventsCleaner *)eventsCleaner
{
    return [self initWithApiKey:apiKey
                  eventsCleaner:eventsCleaner
          notificationsListener:[AMANotificationsListener new]];
}

- (instancetype)initWithApiKey:(NSString *)apiKey
                 eventsCleaner:(AMAEventsCleaner *)eventsCleaner
         notificationsListener:(AMANotificationsListener *)listener
{
    self = [super init];
    if (self != nil) {
        _apiKey = [apiKey copy];
        _eventsCleaner = eventsCleaner;
        _listener = listener;
    }
    return self;
}

#pragma mark - Public -

- (void)subscribeDatabase:(id<AMADatabaseProtocol>)database
{
    switch (database.databaseType) {
        case AMADatabaseTypeInMemory:
            [self subscribeDatabaseToMemoryWarningTrim:database];
            break;

        case AMADatabaseTypePersistent:
            [self subscribeDatabaseToEventsCountTrim:database];
            break;

        default:
            break;
    }
}

- (void)unsubscribeDatabase:(id<AMADatabaseProtocol>)database
{
    [self.listener unsubscribeObject:database];
}

#pragma mark - Private -

- (void)subscribeDatabaseToMemoryWarningTrim:(id<AMADatabaseProtocol>)database
{
    AMAStorageEventsTrimTransaction *transaction =
        [[AMAStorageEventsTrimTransaction alloc] initWithCleaner:self.eventsCleaner];
    AMAPlainStorageTrimmer *trimmer = [[AMAPlainStorageTrimmer alloc] initWithTrimTransaction:transaction];
    __weak __typeof(database) weakDatabase = database;
    [self.listener subscribeObject:database
                    toNotification:UIApplicationDidReceiveMemoryWarningNotification
                      withCallback:^(NSNotification *notification) {
        [trimmer trimDatabase:weakDatabase];
    }];
}

- (void)subscribeDatabaseToEventsCountTrim:(id<AMADatabaseProtocol>)database
{
    AMAStorageEventsTrimTransaction *transaction =
        [[AMAStorageEventsTrimTransaction alloc] initWithCleaner:self.eventsCleaner];
    AMAEventsCountStorageTrimmer *trimmer = [[AMAEventsCountStorageTrimmer alloc] initWithApiKey:self.apiKey
                                                                                 trimTransaction:transaction];
    NSString *expectedApiKey = self.apiKey;
    __weak __typeof(database) weakDatabase = database;
    [self.listener subscribeObject:database
                    toNotification:kAMAReporterDidAddEventNotification
                      withCallback:^(NSNotification *notification) {
        NSString *apiKey = notification.userInfo[kAMAReporterDidAddEventNotificationUserInfoKeyApiKey];
        if (apiKey == nil || [apiKey isEqual:expectedApiKey] == NO) {
            return;
        }
        AMALogInfo(@"Check event count trimming for '%@'. Notification: %@", apiKey, notification);
        [trimmer handleEventAdding];
        [trimmer trimDatabase:weakDatabase];
    }];
}

@end
