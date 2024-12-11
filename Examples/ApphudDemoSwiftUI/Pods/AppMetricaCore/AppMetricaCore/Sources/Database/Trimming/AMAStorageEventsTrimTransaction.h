
#import <Foundation/Foundation.h>

@protocol AMADatabaseProtocol;
@class AMAEventsCleaner;

@interface AMAStorageEventsTrimTransaction : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithCleaner:(AMAEventsCleaner *)cleaner;
- (instancetype)initWithCleaner:(AMAEventsCleaner *)cleaner
                    trimPercent:(double)trimPercent
   importantEventTypePriorities:(NSDictionary *)importantEventTypePriorities;

- (void)performTransactionInDatabase:(id<AMADatabaseProtocol>)database;

@end
