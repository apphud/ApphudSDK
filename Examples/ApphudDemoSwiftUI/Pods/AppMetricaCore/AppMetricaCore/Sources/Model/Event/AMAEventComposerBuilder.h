
#import <Foundation/Foundation.h>

@class AMAEventComposer;
@class AMAReporterStateStorage;
@protocol AMALocationComposer;
@protocol AMANetworkInfoComposer;
@protocol AMAAppEnvironmentComposer;
@protocol AMAEventEnvironmentComposer;
@protocol AMAProfileIdComposer;
@protocol AMALocationEnabledComposer;
@protocol AMAOpenIDComposer;
@protocol AMAExtrasComposer;

@interface AMAEventComposerBuilder : NSObject

@property(nonatomic, strong, readonly) id<AMAProfileIdComposer> profileIdComposer;
@property(nonatomic, strong, readonly) id<AMALocationComposer> locationComposer;
@property(nonatomic, strong, readonly) id<AMALocationEnabledComposer> locationEnabledComposer;
@property(nonatomic, strong, readonly) id<AMAAppEnvironmentComposer> appEnvironmentComposer;
@property(nonatomic, strong, readonly) id<AMAEventEnvironmentComposer> eventEnvironmentComposer;
@property(nonatomic, strong, readonly) id<AMAOpenIDComposer> openIDComposer;
@property(nonatomic, strong, readonly) id<AMAExtrasComposer> extrasComposer;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithStorage:(AMAReporterStateStorage *)storage;
- (void)addProfileIdComposer:(id<AMAProfileIdComposer>)profileIdComposer;
- (void)addOpenIDComposer:(id<AMAOpenIDComposer>)openIDComposer;
- (void)addLocationComposer:(id<AMALocationComposer>)locationComposer;
- (void)addLocationEnabledComposer:(id<AMALocationEnabledComposer>)locationEnabledComposer;
- (void)addAppEnvironmentComposer:(id<AMAAppEnvironmentComposer>)appEnvironmentComposer;
- (void)addEventEnvironmentComposer:(id<AMAEventEnvironmentComposer>)eventEnvironmentComposer;
- (void)addExtrasComposer:(id<AMAExtrasComposer>)extrasComposer;
- (AMAEventComposer *)build;

+ (instancetype)defaultBuilderWithStorage:(AMAReporterStateStorage *)storage;

@end
