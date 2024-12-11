
#import "AMACore.h"
#import "AMAAdProvider.h"

@interface AMAAdProvider ()

@property (nonatomic, strong) id<AMAAdProviding> externalProvider;

@end

@implementation AMAAdProvider

#pragma mark - Public -

+ (instancetype)sharedInstance
{
    static dispatch_once_t pred;
    static AMAAdProvider *shared = nil;
    dispatch_once(&pred, ^{
        shared = [[[self class] alloc] init];
    });
    return shared;
}

- (BOOL)isAdvertisingTrackingEnabled
{
    @synchronized (self) {
        if (self.externalProvider != nil) {
            return [self.externalProvider isAdvertisingTrackingEnabled];
        }
        else {
            return NO;
        }
    }
}

- (NSUUID *)advertisingIdentifier
{
    @synchronized (self) {
        if (self.externalProvider != nil) {
            return [self.externalProvider advertisingIdentifier];
        }
        else {
            return nil;
        }
    }
}

- (NSUInteger)ATTStatus
{
    @synchronized (self) {
        if (self.externalProvider != nil) {
            return [self.externalProvider ATTStatus];
        }
        else {
            return AMATrackingManagerAuthorizationStatusNotDetermined;
        }
    }
}

- (void)setupAdProvider:(id<AMAAdProviding>)adProvider
{
    @synchronized (self) {
        self.externalProvider = adProvider;
    }
}

@end
