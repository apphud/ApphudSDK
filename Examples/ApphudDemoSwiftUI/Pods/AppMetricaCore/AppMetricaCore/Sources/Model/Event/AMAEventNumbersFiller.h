
#import <Foundation/Foundation.h>

@protocol AMAKeyValueStoring;
@class AMAEvent;
@class AMASession;
@class AMARollbackHolder;

NS_ASSUME_NONNULL_BEGIN

@interface AMAEventNumbersFiller : NSObject

- (void)fillNumbersOfEvent:(AMAEvent *)event
                   session:(AMASession *)session
                   storage:(id<AMAKeyValueStoring>)storage
                  rollback:(AMARollbackHolder *)rollbackHolder
                     error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
