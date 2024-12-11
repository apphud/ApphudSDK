
#import <Foundation/Foundation.h>
#import "AMALocationStorage.h"

@interface AMALocationStorageState : NSObject <AMALSSLocationsProviding, AMALSSVisitsProviding>

@property (nonatomic, assign, readonly) unsigned long long locationIdentifier;
@property (nonatomic, assign, readonly) unsigned long long visitIdentifier;
@property (nonatomic, assign, readonly) unsigned long long requestIdentifier;
@property (nonatomic, assign, readonly) NSUInteger locationsCount;
@property (nonatomic, strong, readonly) NSDate *firstLocationDate;
@property (nonatomic, assign, readonly) NSUInteger visitsCount;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithLocationIdentifier:(unsigned long long)locationIdentifier
                           visitIdentifier:(unsigned long long)visitIdentifier
                         requestIdentifier:(unsigned long long)requestIdentifier
                            locationsCount:(NSUInteger)locationsCount
                         firstLocationDate:(NSDate *)firstLocationDate
                               visitsCount:(NSUInteger)visitsCount;

- (instancetype)stateByChangingLocationIdentifier:(unsigned long long)identifier
                                   locationsCount:(NSUInteger)count
                                firstLocationDate:(NSDate *)date;

- (instancetype)stateByChangingLocationsCount:(NSUInteger)count
                            firstLocationDate:(NSDate *)date;

- (instancetype)stateByChangingVisitIdentifier:(unsigned long long)identifier
                                   visitsCount:(NSUInteger)count;

- (instancetype)stateByChangingRequestIdentifier:(unsigned long long)identifier;

- (instancetype)stateByChangingVisitsCount:(NSUInteger)count;

@end
