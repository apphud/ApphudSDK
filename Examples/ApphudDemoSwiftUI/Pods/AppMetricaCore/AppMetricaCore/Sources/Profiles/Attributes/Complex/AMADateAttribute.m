
#import "AMADateAttribute.h"
#import "AMAInvalidUserProfileUpdateFactory.h"
#import "AMAStringAttribute.h"

@interface AMADateAttribute ()

@property (nonatomic, strong, readonly) AMAStringAttribute *stringAttribute;

@end

@implementation AMADateAttribute

- (instancetype)initWithStringAttribute:(AMAStringAttribute *)stringAttribute
{
    self = [super init];
    if (self != nil) {
        _stringAttribute = stringAttribute;
    }
    return self;
}

+ (NSArray *)dateComponentFormats
{
    static NSArray *formats = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formats = @[ @"%04d", @"-%02d", @"-%02d" ];
    });
    return formats;
}

- (AMAUserProfileUpdate *)invalidDateUserProfileUpdate
{
    return [AMAInvalidUserProfileUpdateFactory invalidDateUpdateWithAttributeName:self.stringAttribute.name];
}

- (AMAUserProfileUpdate *)updateWithDateComponentsArray:(NSArray *)dateComponentsArray
{
    NSMutableString *dateString = [NSMutableString string];
    NSArray *formats = [[self class] dateComponentFormats];
    [dateComponentsArray enumerateObjectsUsingBlock:^(NSNumber *component, NSUInteger idx, BOOL *stop) {
        NSString *format = formats[idx];
        [dateString appendFormat:format, (int)[component integerValue]];
    }];
    return [self.stringAttribute withValue:[dateString copy]];
}

- (NSArray *)dateComponentsArrayWithDateComponents:(NSDateComponents *)dateComponents
{
    if (dateComponents == nil) {
        return nil;
    }

    NSMutableArray *componentsArray = [NSMutableArray array];
    if (dateComponents.year != NSDateComponentUndefined) {
        [componentsArray addObject:@(dateComponents.year)];
        if (dateComponents.month != NSDateComponentUndefined) {
            [componentsArray addObject:@(dateComponents.month)];
            if (dateComponents.day != NSDateComponentUndefined) {
                [componentsArray addObject:@(dateComponents.day)];
            }
        }
    }
    return componentsArray;
}

- (AMAUserProfileUpdate *)withAge:(NSUInteger)value
{
    NSDateComponents *components = [[NSCalendar currentCalendar] components:NSCalendarUnitYear
                                                                   fromDate:[NSDate date]];
    return [self withYear:(NSUInteger)(components.year - (NSInteger)value)];
}

- (AMAUserProfileUpdate *)withYear:(NSUInteger)year
{
    return [self updateWithDateComponentsArray:@[ @(year) ]];
}

- (AMAUserProfileUpdate *)withYear:(NSUInteger)year month:(NSUInteger)month
{
    return [self updateWithDateComponentsArray:@[ @(year), @(month) ]];
}

- (AMAUserProfileUpdate *)withYear:(NSUInteger)year month:(NSUInteger)month day:(NSUInteger)day
{
    return [self updateWithDateComponentsArray:@[ @(year), @(month), @(day) ]];
}

- (AMAUserProfileUpdate *)withDateComponents:(NSDateComponents *)dateComponents
{
    AMAUserProfileUpdate *userProfileUpdate = nil;
    NSArray *componentsArray = [self dateComponentsArrayWithDateComponents:dateComponents];
    if (componentsArray.count != 0) {
        userProfileUpdate = [self updateWithDateComponentsArray:componentsArray];
    }
    else {
        userProfileUpdate = [self invalidDateUserProfileUpdate];
    }
    return userProfileUpdate;
}

- (AMAUserProfileUpdate *)withValueReset
{
    return [self.stringAttribute withValueReset];
}

@end
