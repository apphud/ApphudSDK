
#import <Foundation/Foundation.h>

@class AMALocationRequest;
@class AMALocationSerializer;
@class AMALocationStorage;
@class AMALocationCollectingConfiguration;
@protocol AMADataEncoding;

@interface AMALocationRequestProvider : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithStorage:(AMALocationStorage *)storage
                  configuration:(AMALocationCollectingConfiguration *)configuration;
- (instancetype)initWithStorage:(AMALocationStorage *)storage
                  configuration:(AMALocationCollectingConfiguration *)configuration
                     serializer:(AMALocationSerializer *)serializer
                        encoder:(id<AMADataEncoding>)encoder;

- (AMALocationRequest *)nextLocationsRequest;
- (AMALocationRequest *)nextVisitsRequest;

@end
