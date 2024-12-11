
#import <Foundation/Foundation.h>

@class AMALocation;
@class AMAVisit;
@class AMALocationCollectingConfiguration;
@class AMALocationSerializer;
@protocol AMADatabaseProtocol;
@protocol AMADataEncoding;

@protocol AMALocationStorageStateProviding <NSObject>

@property (nonatomic, assign, readonly) unsigned long long requestIdentifier;

@end

@protocol AMALSSLocationsProviding <AMALocationStorageStateProviding>

@property (nonatomic, assign, readonly) NSUInteger locationsCount;
@property (nonatomic, strong, readonly) NSDate *firstLocationDate;

@end

@protocol AMALSSVisitsProviding <AMALocationStorageStateProviding>

@property (nonatomic, assign, readonly) NSUInteger visitsCount;

@end

@interface AMALocationStorage : NSObject

@property (nonatomic, strong, readonly) id<AMALSSLocationsProviding, AMALSSVisitsProviding> locationStorageState;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithConfiguration:(AMALocationCollectingConfiguration *)configuration;
- (instancetype)initWithConfiguration:(AMALocationCollectingConfiguration *)configuration
                           serializer:(AMALocationSerializer *)serializer
                             database:(id<AMADatabaseProtocol>)database
                              crypter:(id<AMADataEncoding>)crypter;

- (void)addLocations:(NSArray<AMALocation *> *)locations;
- (NSArray<AMALocation *> *)locationsWithLimit:(NSUInteger)locationsLimit;
- (void)purgeLocationsWithIdentifiers:(NSArray<NSNumber *> *)locationIdentifiers;

- (void)addVisit:(AMAVisit *)visit;
- (NSArray<AMAVisit *> *)visitsWithLimit:(NSUInteger)visitsLimit;
- (void)purgeVisitsWithIdentifiers:(NSArray<NSNumber *> *)visitIdentifiers;

- (void)incrementRequestIdentifier;

@end
