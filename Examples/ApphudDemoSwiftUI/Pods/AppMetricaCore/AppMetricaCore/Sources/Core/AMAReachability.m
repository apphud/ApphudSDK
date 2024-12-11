
#import "AMACore.h"
#import "AMAReachability.h"
#import "AMAMetricaDynamicFrameworks.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <AppMetricaPlatform/AppMetricaPlatform.h>

NSString *const kAMAReachabilityStatusDidChange = @"kAMAReachabilityStatusDidChange";

static NSString *const kAMAReachabilityHost = @"itunes.apple.com";

typedef SCNetworkReachabilityRef (*amaCreateWithName)(CFAllocatorRef, const char *);
typedef Boolean (*amaSetCallback)(SCNetworkReachabilityRef,
                                  SCNetworkReachabilityCallBack,
                                  SCNetworkReachabilityContext *);
typedef Boolean (*amaSetDispatchQueue)(SCNetworkReachabilityRef, dispatch_queue_t);


@interface AMAReachability ()

@property (nonatomic, assign) SCNetworkReachabilityRef reachabilityRef;
@property (nonatomic, assign) SCNetworkReachabilityFlags flags;
@property (nonatomic, assign) AMAReachabilityStatus status;
@property (nonatomic, strong) dispatch_queue_t callbackQueue;
@property (nonatomic, strong, readonly) AMAFramework *framework;

@property (nonatomic, assign, readonly) amaCreateWithName createWithName;
@property (nonatomic, assign, readonly) amaSetCallback setCallback;
@property (nonatomic, assign, readonly) amaSetDispatchQueue setDispatchQueue;

@end

static void AMAReachabilityCallback(SCNetworkReachabilityRef __unused target, SCNetworkReachabilityFlags flags, void __unused *info)
{
    [[AMAReachability sharedInstance] setFlags:flags];
}

@implementation AMAReachability

@synthesize flags = _flags;

+ (instancetype)sharedInstance
{
    static dispatch_once_t pred;
    static AMAReachability *shared = nil;
    dispatch_once(&pred, ^{
        shared = [[[self class] alloc] init];
    });
    return shared;
}

- (id)init
{
    self = [super init];
    if (self != nil) {
        _status = AMAReachabilityStatusUnknown;
        _callbackQueue = [AMAQueuesFactory serialQueueForIdentifierObject:self domain:[AMAPlatformDescription SDKBundleName]];

        _framework = [AMAMetricaDynamicFrameworks sConfiguration];
        _createWithName = [self.framework functionFromString:@"SCNetworkReachabilityCreateWithName"];
        _setCallback = [self.framework functionFromString:@"SCNetworkReachabilitySetCallback"];
        _setDispatchQueue = [self.framework functionFromString:@"SCNetworkReachabilitySetDispatchQueue"];
    }
    return self;
}

- (void)dealloc
{
    [self shutdown];
}

#pragma mark - Public -

- (void)start
{
    @synchronized(self) {
        if ([self isStarted] == NO) {
            [self scheduleReachabilityStatusUpdates];
        }
    }
}

- (void)shutdown
{
    @synchronized(self) {
        if ([self isStarted]) {
            [self unscheduleReachabilityStatusUpdates];
        }
    }
}

- (AMAReachabilityStatus)status
{
    @synchronized(self) {
        return _status;
    }
}
 
- (BOOL)isNetworkReachable
{
    AMAReachabilityStatus status = self.status;
    return status != AMAReachabilityStatusUnknown && status != AMAReachabilityStatusNotReachable;
}

#pragma mark - Private -

- (BOOL)canMakeReachabilityFunctionsCall
{
    return self.createWithName != NULL && self.setCallback != NULL && self.setDispatchQueue != NULL;
}

- (void)scheduleReachabilityStatusUpdates
{
    if ([self canMakeReachabilityFunctionsCall] == NO) {
        AMALogInfo(@"Can't make reachability functions");
        return;
    }

    const char *host = [kAMAReachabilityHost UTF8String];
    self.reachabilityRef = self.createWithName(NULL, host);
    AMALogInfo(@"Reachability host: %s", host);

    if (self.reachabilityRef != NULL &&
        self.setCallback(self.reachabilityRef, AMAReachabilityCallback, NULL)) {
        self.setDispatchQueue(self.reachabilityRef, self.callbackQueue);
        AMALogInfo(@"Reachability checks started");
    }
    else {
        AMALogInfo(@"Can't start reachability checks");
    }
}

- (void)unscheduleReachabilityStatusUpdates
{
    if (_reachabilityRef != NULL  && [self canMakeReachabilityFunctionsCall]) {
        self.setDispatchQueue(_reachabilityRef, NULL);
        CFRelease(_reachabilityRef);
        _reachabilityRef = NULL;
        AMALogInfo(@"Reachability checks stopped");
    }
}

- (BOOL)isStarted
{
    return (self.reachabilityRef != NULL);
}

- (BOOL)isReachable
{
    BOOL reachable = YES;

    SCNetworkConnectionFlags flags = self.flags;
    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) {
        reachable = NO;
    }

    if (reachable) {
        SCNetworkReachabilityFlags noConnectionFlags = (kSCNetworkReachabilityFlagsConnectionRequired |
                                                        kSCNetworkReachabilityFlagsTransientConnection);
        if ((flags & noConnectionFlags) == noConnectionFlags) {
            reachable = NO;
        }
    }
    return reachable;
}

- (BOOL)isReachableViaWiFi
{
    SCNetworkConnectionFlags flags = self.flags;
    BOOL isReachableViaWWAN = (flags & kSCNetworkReachabilityFlagsIsWWAN) != 0;
    return (isReachableViaWWAN == NO);
}

- (void)setFlags:(SCNetworkReachabilityFlags)flags
{
    @synchronized(self) {
        if (_flags != flags) {
            _flags = flags;
        }
    }

    [self updateStatus];
}

- (SCNetworkReachabilityFlags)flags
{
    @synchronized(self) {
        return _flags;
    }
}

- (void)updateStatus
{
    BOOL shouldNotify = NO;

    @synchronized(self) {
        AMAReachabilityStatus updatedStatus = [self currentReachabilityStatus];
        shouldNotify = self.status != updatedStatus;
        self.status = updatedStatus;
    }

    AMALogInfo(@"Reachability status: %lu", (unsigned long)self.status);
    if (shouldNotify) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kAMAReachabilityStatusDidChange
                                                            object:self];
    }
}

- (AMAReachabilityStatus)currentReachabilityStatus
{
    AMAReachabilityStatus status = AMAReachabilityStatusUnknown;
    if ([self isStarted] == NO) {
        return status;
    }
    if ([self isReachable]) {
        if ([self isReachableViaWiFi]) {
            status = AMAReachabilityStatusReachableViaWiFi;
        }
        else {
            status = AMAReachabilityStatusReachableViaWWAN;
        }
    }
    else {
        status = AMAReachabilityStatusNotReachable;
    }
    return status;
}

@end
