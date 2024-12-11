
#import <AppMetricaPlatform/AppMetricaPlatform.h>
#import "AMASession.h"
#import "AMADate.h"

@implementation AMASession

- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:AMASession.class] == NO) {
        return NO;
    }
    
    AMASession *session = (AMASession *)object;
    
    return ([self bothValuesAreNilOrValue:self.oid isEqualToValue:session.oid] &&
            [self bothValuesAreNilOrValue:self.startDate isEqualToValue:session.startDate] &&
            [self bothValuesAreNilOrValue:self.lastEventTime isEqualToValue:session.lastEventTime] &&
            [self bothValuesAreNilOrValue:self.pauseTime isEqualToValue:session.pauseTime] &&
            [self bothValuesAreNilOrValue:self.appState isEqualToValue:session.appState] &&
            self.isFinished == session.isFinished &&
            self.eventSeq == session.eventSeq &&
            self.type == session.type &&
            [self bothValuesAreNilOrValue:self.sessionID isEqualToValue:session.sessionID] &&
            [self bothValuesAreNilOrValue:self.attributionID isEqualToValue:session.attributionID]);
}

- (NSUInteger)hash
{
    NSUInteger prime = 31;
    NSUInteger result = 1;
    
    result = prime * result + [self.oid hash];
    result = prime * result + [self.startDate hash];
    result = prime * result + [self.lastEventTime hash];
    result = prime * result + [self.pauseTime hash];
    result = prime * result + [self.appState hash];
    result = prime * result + (self.isFinished ? 1 : 0);
    result = prime * result + self.eventSeq;
    result = prime * result + self.type;
    result = prime * result + [self.sessionID hash];
    result = prime * result + [self.attributionID hash];
    
    return result;
}

- (BOOL)bothValuesAreNilOrValue:(id)value isEqualToValue:(id)anotherValue
{
    return (value == nil && anotherValue == nil) || [value isEqual:anotherValue];
}

#if AMA_ALLOW_DESCRIPTIONS
- (NSString *)description
{
    NSString *descr = [super description];
    return [NSString stringWithFormat:@"%@, startTime: %@, pauseTime: %@, lastEventTime: %@, eventSeq: %lu",
            descr, self.startDate, self.pauseTime, self.lastEventTime, (unsigned long)self.eventSeq];
}
#endif

@end
