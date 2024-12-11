
#import <Foundation/Foundation.h>
#import "AMAEventsCleanupReasonType.h"

@class AMAEvent;

@interface AMAEventsCleanupInfo : NSObject

@property (nonatomic, assign, readonly) BOOL shouldReport;
@property (nonatomic, copy, readonly) NSArray<NSNumber *> *eventOids;
@property (nonatomic, copy, readonly) NSDictionary *cleanupReport;

@property (nonatomic, assign) NSInteger actualDeletedNumber;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithReasonType:(AMAEventsCleanupReasonType)reasonType;

- (BOOL)addEvent:(AMAEvent *)event;
- (void)addEventByOid:(NSNumber *)oid;

@end
