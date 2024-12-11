
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, AMAEventsCleanupReasonType) {
    AMAEventsCleanupReasonTypeSuccessfulReport,
    AMAEventsCleanupReasonTypeBadRequest,
    AMAEventsCleanupReasonTypeEntityTooLarge,
    AMAEventsCleanupReasonTypeDBOverflow,
};
