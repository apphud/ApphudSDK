
#import "AMABuildUID.h"

static NSString *const kAMABuildUIDDateKey = @"date";

@interface AMABuildUID ()

@property (nonatomic, copy, readonly) NSDate *buildDate;

@end

@implementation AMABuildUID

- (instancetype)initWithString:(NSString *)buildUIDString {
    if (buildUIDString == nil) {
        return nil;
    }
    NSTimeInterval timeIntervalSince1970 = [buildUIDString doubleValue];
    if (timeIntervalSince1970 <= 0) {
        return nil;
    }
    NSDate *buildUIDDate = [NSDate dateWithTimeIntervalSince1970:timeIntervalSince1970];
    return [self initWithDate:buildUIDDate];
}

- (instancetype)initWithDate:(NSDate *)buildUIDDate
{
    if (buildUIDDate == nil) {
        return nil;
    }

    self = [super init];
    if (self != nil) {
        _buildDate = [buildUIDDate copy];
    }
    return self;
}

- (NSString *)stringValue
{
    return [NSString stringWithFormat:@"%lu", (unsigned long)[self.buildDate timeIntervalSince1970]];
}

+ (instancetype)buildUID
{
    NSDate *buildDate = [[self class] libraryCompilationDate];
    return [[AMABuildUID alloc] initWithDate:buildDate];
}

+ (NSDate *)libraryCompilationDate
{
    NSDate *libraryCompilationDate = nil;
#ifdef __DATE__
    NSString *compileDateTimeString;
#ifdef __TIME__
    compileDateTimeString = [NSString stringWithFormat:@"%s %s", __DATE__, __TIME__];
#else /* __TIME__ */
    compileDateTimeString = [NSString stringWithFormat:@"%s 00:00:00", __DATE__];
#endif /* __TIME__ */
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"MMM d yyyy HH:mm:ss";
    dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
    dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    libraryCompilationDate = [dateFormatter dateFromString:compileDateTimeString];
#else /* __DATE__ */
    libraryCompilationDate = [NSDate dateWithTimeIntervalSince1970:0];
#endif /* __DATE__ */
    return libraryCompilationDate;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    NSDate *date = [aDecoder decodeObjectOfClass:[NSDate class] forKey:kAMABuildUIDDateKey];
    return [self initWithDate:date];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.buildDate forKey:kAMABuildUIDDateKey];
}

#pragma mark - NSObject

- (NSUInteger)hash
{
    return [self.buildDate hash];
}

- (BOOL)isEqual:(id)object
{
    AMABuildUID *other = object;
    BOOL isEqual = [other isKindOfClass:[self class]];
    isEqual = isEqual && (other.buildDate == self.buildDate || [other.buildDate isEqualToDate:self.buildDate]);
    return isEqual;
}

- (NSComparisonResult)compare:(AMABuildUID *)other
{
    return [self.buildDate compare:other.buildDate];
}

#if AMA_ALLOW_DESCRIPTIONS
- (NSString *)description
{
    return [NSString stringWithFormat:@"%@:%@", [super description], self.stringValue];
}
#endif

@end
