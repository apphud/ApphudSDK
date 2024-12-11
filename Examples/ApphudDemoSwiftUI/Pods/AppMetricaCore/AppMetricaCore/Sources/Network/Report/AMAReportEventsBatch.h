
#import <Foundation/Foundation.h>

@class AMASession;
@class AMAEvent;

@interface AMAReportEventsBatch : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithSession:(AMASession *)session
                 appEnvironment:(NSDictionary *)appEnvironment
                         events:(NSArray<AMAEvent *> *)events;

@property (nonatomic, strong, readonly) AMASession *session;
@property (nonatomic, copy, readonly) NSDictionary *appEnvironment;
@property (nonatomic, copy, readonly) NSArray<AMAEvent *> *events;

@end
