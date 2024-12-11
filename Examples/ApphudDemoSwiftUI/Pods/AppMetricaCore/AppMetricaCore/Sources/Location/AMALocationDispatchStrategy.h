
#import <Foundation/Foundation.h>

@class AMALocationStorage;
@class AMALocationCollectingConfiguration;
@protocol AMADateProviding;

@interface AMALocationDispatchStrategy : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithStorage:(AMALocationStorage *)storage
                  configuration:(AMALocationCollectingConfiguration *)configuration;

- (instancetype)initWithStorage:(AMALocationStorage *)storage
                  configuration:(AMALocationCollectingConfiguration *)configuration
                   dateProvider:(id<AMADateProviding>)dateProvider;

- (BOOL)shouldSendLocation;
- (BOOL)shouldSendVisit;
- (void)handleRequestFailure;

@end
