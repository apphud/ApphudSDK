
#import "AMAStackTraceElement.h"

@implementation AMAStackTraceElement

- (instancetype)init
{
    return [self initWithClassName:nil fileName:nil line:nil column:nil methodName:nil];
}

- (instancetype)initWithClassName:(nullable NSString *)className
                         fileName:(nullable NSString *)fileName
                             line:(nullable NSNumber *)line
                           column:(nullable NSNumber *)column
                       methodName:(nullable NSString *)methodName
{
    self = [super init];
    if (self != nil) {
        _className = [className copy];
        _fileName = [fileName copy];
        _line = line;
        _column = column;
        _methodName = [methodName copy];
    }
    return self;
}

@end
