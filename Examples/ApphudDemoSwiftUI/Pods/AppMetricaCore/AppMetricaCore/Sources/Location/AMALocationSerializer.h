
#import <Foundation/Foundation.h>

@class AMALocation;
@class AMAVisit;

@interface AMALocationSerializer : NSObject

- (NSData *)dataForLocations:(NSArray<AMALocation *> *)locations visits:(NSArray<AMAVisit *> *)visits;
- (NSData *)dataForLocations:(NSArray<AMALocation *> *)locations;
- (NSArray<AMALocation *> *)locationsForData:(NSData *)data;
- (NSData *)dataForVisits:(NSArray<AMAVisit *> *)visits;
- (NSArray<AMAVisit *> *)visitsForData:(NSData *)data;

@end
