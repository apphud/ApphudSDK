
#import "AMAEventTypeResolver.h"

@implementation AMAEventTypeResolver

+ (BOOL)isEventTypeReserved:(NSUInteger)eventType
{
    const NSInteger initReservedEvent = 1;
    const NSInteger firstReservedEvent = 13;

    return (eventType == initReservedEvent || eventType == firstReservedEvent);
}

@end
