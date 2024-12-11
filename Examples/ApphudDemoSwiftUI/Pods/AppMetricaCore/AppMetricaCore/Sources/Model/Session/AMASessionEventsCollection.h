
#import <Foundation/Foundation.h>

@class AMASession;
@class AMAEvent;

@interface AMASessionEventsCollection : NSObject

@property (nonatomic, strong, readonly) AMASession *session;
@property (nonatomic, strong, readonly) NSArray<AMAEvent *> *events;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithSession:(AMASession *)session events:(NSArray<AMAEvent *> *)events;

@end
