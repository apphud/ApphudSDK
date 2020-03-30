//
//  ApphudObjcExtensions.m
//  Adjust
//
//  Created by Renat on 24.03.2020.
//

#import "ApphudObjcExtensions.h"

@implementation ApphudObjcExtensions

+ (void)initialize {
    [[self class] saveFbAnonID];
}

+ (void)saveFbAnonID {
#if TARGET_OS_TV
    return;
#else
    Class class = NSClassFromString(@"FBSDKBasicUtility");
    SEL selector = NSSelectorFromString(@"retrievePersistedAnonymousID");
    
    if (class != nil && [class respondsToSelector:selector]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            NSString *fbAnonymousId = (NSString *)[class performSelector:selector];
        #pragma clang diagnostic pop
            if ([fbAnonymousId isKindOfClass:[NSString class]]) {
                [[NSUserDefaults standardUserDefaults] setObject:fbAnonymousId forKey:@"ApphudFbAnonID"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
        #endif
    }
}

@end
