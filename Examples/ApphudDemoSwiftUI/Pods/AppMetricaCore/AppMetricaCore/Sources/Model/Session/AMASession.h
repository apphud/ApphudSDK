
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, AMASessionType) {
    AMASessionTypeGeneral = 0,
    AMASessionTypeBackground
};

@class AMANetworkInfo;
@class AMAApplicationState;
@class AMADate;

@interface AMASession : NSObject

@property (nonatomic, strong) NSNumber *oid;
@property (nonatomic, strong) AMADate *startDate;
@property (nonatomic, strong) NSDate *lastEventTime;
@property (nonatomic, strong) NSDate *pauseTime;
@property (nonatomic, copy) AMAApplicationState *appState;
@property (nonatomic, assign, getter = isFinished) BOOL finished;
@property (nonatomic, assign) NSUInteger eventSeq;
@property (nonatomic, assign) AMASessionType type;
@property (nonatomic, strong) NSNumber *sessionID;
@property (nonatomic, copy) NSString *attributionID;

@end
