
#import "AMADateLogMessageFormatter.h"
#import "AMALogMessage.h"

@interface AMADateLogMessageFormatter ()

@property (nonatomic, assign) NSCalendarUnit calendarUnitFlags;
@property (nonatomic, strong) NSCalendar *calendar;

@end

@implementation AMADateLogMessageFormatter

- (instancetype)init
{
    self = [super init];
    if (self) {
        _calendarUnitFlags = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
        _calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    }

    return self;
}

- (NSString *)messageToString:(AMALogMessage *)message
{
    if (message.timestamp == nil) {
        return nil;
    }

    NSDateComponents *components = [self.calendar components:self.calendarUnitFlags
                                                    fromDate:message.timestamp];

    NSTimeInterval epoch = [message.timestamp timeIntervalSinceReferenceDate];
    int milliseconds = (int)((epoch - floor(epoch)) * 1000);

    char ts[13] = "";
    snprintf(ts, sizeof(ts), "%02ld:%02ld:%02ld:%03d",
             (long)components.hour,
             (long)components.minute,
             (long)components.second,
             milliseconds);
    NSString *dateString = [NSString stringWithUTF8String:ts];
    return dateString;
}

@end
