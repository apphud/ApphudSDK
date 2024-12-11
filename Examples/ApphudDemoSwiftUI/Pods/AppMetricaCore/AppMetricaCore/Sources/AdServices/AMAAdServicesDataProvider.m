
#import "AMACore.h"
#import "AMAAdServicesDataProvider.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140300
    #if !TARGET_OS_TV
        #import <AdServices/AdServices.h>
    #endif
#endif

#import "AMAFramework.h"
#import "AMAMetricaDynamicFrameworks.h"

@interface AMAAdServicesDataProvider ()

@property (nonatomic, strong, readonly) AMAFramework *adServices;

@end

@implementation AMAAdServicesDataProvider

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _adServices = AMAMetricaDynamicFrameworks.adServices;
    }

    return self;
}

- (NSString *)tokenWithError:(NSError **)error
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140300
#if !TARGET_OS_TV && !TARGET_OS_SIMULATOR
    if (@available(iOS 14.3, *)) {
        NSError *localError = nil;
        Class aaAttribution = [self.adServices classFromString:@"AAAttribution"];
        if (aaAttribution != Nil) {
            NSString *token = [aaAttribution attributionTokenWithError:&localError];

            if (token != nil) {
                AMALogInfo(@"AdServices token successfully received!");
            }
            else if (localError != nil) {
                AMALogInfo(@"AdServices attribution token error: %@", localError);
                [AMAErrorUtilities fillError:error withError:localError];
            }
            else {
                AMALogInfo(@"AdServices available, but received unexpected `nil` token");
                [AMAErrorUtilities fillError:error withInternalErrorName:@"AdServices available. Nil token"];
            }

            return token;
        }
    }
#endif
#endif
    AMALogInfo(@"AdServices unavailable");
    [AMAErrorUtilities fillError:error withInternalErrorName:@"AdServices unavailable"];
    return nil;
}

@end
