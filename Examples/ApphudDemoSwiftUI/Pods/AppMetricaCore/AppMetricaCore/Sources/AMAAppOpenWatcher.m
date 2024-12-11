
#import "AMACore.h"
#import "AMAAppOpenWatcher.h"
#import "AMADeepLinkController.h"
#import <UIKit/UIKit.h>

@interface AMAAppOpenWatcher ()

@property (nonatomic, strong, readonly) NSNotificationCenter *notificationCenter;
@property (atomic, strong) AMADeepLinkController *deepLinkController;

@end

@implementation AMAAppOpenWatcher

- (instancetype)init
{
    return [self initWithNotificationCenter:[NSNotificationCenter defaultCenter]];
}

#pragma mark - Public -

- (instancetype)initWithNotificationCenter:(NSNotificationCenter *)center
{
    self = [super init];
    if (self != nil) {
        _notificationCenter = center;
    }

    return self;
}

- (void)startWatchingWithDeeplinkController:(AMADeepLinkController *)controller
{
    AMALogInfo(@"Start");
    self.deepLinkController = controller;
    [self.notificationCenter addObserver:self
                                selector:@selector(didFinishLaunching:)
                                    name:UIApplicationDidFinishLaunchingNotification
                                  object:nil];
}

#pragma mark - NSNotificationCenter callback

- (void)didFinishLaunching:(NSNotification *)notification
{
    AMALogInfo(@"User info: %@", notification.userInfo);
    NSURL *url = [self extractDeeplink:notification.userInfo];
    [self.deepLinkController reportUrl:url ofType:kAMADLControllerUrlTypeOpen isAuto:YES];
}

#pragma mark - Private -

- (NSURL *)extractDeeplink:(NSDictionary *)userInfo
{
    NSURL *__block openUrl = nil;
    //Deeplink
    if ([userInfo[UIApplicationLaunchOptionsURLKey] isKindOfClass:NSURL.class]) {
        openUrl = userInfo[UIApplicationLaunchOptionsURLKey];
    }
    //Universal link
    if (openUrl.absoluteString.length == 0) {
        if ([userInfo[UIApplicationLaunchOptionsUserActivityDictionaryKey] isKindOfClass:NSDictionary.class]) {
            NSDictionary *userActivity = userInfo[UIApplicationLaunchOptionsUserActivityDictionaryKey];
            [userActivity enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
                if ([value isKindOfClass:NSUserActivity.class]) {
                    NSUserActivity *activity = value;
                    openUrl = activity.webpageURL;
                    *stop = YES;
                }
            }];
        }
    }
    return openUrl;
}

@end
