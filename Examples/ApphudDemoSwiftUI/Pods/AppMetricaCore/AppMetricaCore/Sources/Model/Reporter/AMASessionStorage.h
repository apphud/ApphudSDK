
#import <Foundation/Foundation.h>
#import "AMASession.h"

@class AMASessionSerializer;
@class AMAReporterStateStorage;
@protocol AMADatabaseProtocol;

@interface AMASessionStorage : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithDatabase:(id<AMADatabaseProtocol>)database
                      serializer:(AMASessionSerializer *)serializer
                    stateStorage:(AMAReporterStateStorage *)stateStorage;

- (AMASession *)lastSessionWithError:(NSError **)error;
- (AMASession *)lastGeneralSessionWithError:(NSError **)error;
- (AMASession *)lastSessionWithType:(AMASessionType)type error:(NSError **)error;
- (AMASession *)previousSessionForSession:(AMASession *)session error:(NSError **)error;

- (AMASession *)newGeneralSessionCreatedAt:(NSDate *)date error:(NSError **)error;
- (AMASession *)newBackgroundSessionCreatedAt:(NSDate *)date error:(NSError **)error;
- (AMASession *)newFinishedBackgroundSessionCreatedAt:(NSDate *)date
                                             appState:(AMAApplicationState *)appState
                                                error:(NSError **)error;
- (AMASession *)newSessionWithNextAttributionIDCreatedAt:(NSDate *)date
                                                    type:(AMASessionType)type
                                                   error:(NSError **)error;

- (BOOL)saveSessionAsLastSession:(AMASession *)session error:(NSError **)error;
- (BOOL)updateSession:(AMASession *)session pauseTime:(NSDate *)pauseTime error:(NSError **)error;
- (BOOL)updateSession:(AMASession *)session appState:(AMAApplicationState *)appState error:(NSError **)error;
- (BOOL)finishSession:(AMASession *)session atDate:(NSDate *)date error:(NSError **)error;

@end
