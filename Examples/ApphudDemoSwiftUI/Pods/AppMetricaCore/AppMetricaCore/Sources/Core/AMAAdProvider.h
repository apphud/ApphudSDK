
#import <Foundation/Foundation.h>

@protocol AMAAdProviding;

@interface AMAAdProvider : NSObject

+ (instancetype)sharedInstance;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (BOOL)isAdvertisingTrackingEnabled;
- (NSUUID *)advertisingIdentifier;
- (NSUInteger)ATTStatus API_AVAILABLE(ios(14.0), tvos(14.0));

- (void)setupAdProvider:(id<AMAAdProviding>)adProvider;

@end
