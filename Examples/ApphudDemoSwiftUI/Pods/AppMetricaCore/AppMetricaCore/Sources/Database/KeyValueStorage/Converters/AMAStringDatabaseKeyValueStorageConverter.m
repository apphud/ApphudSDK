
#import "AMACore.h"
#import "AMAStringDatabaseKeyValueStorageConverter.h"

static NSString *const kAMATrueValue = @"1";
static NSString *const kAMAFalseValue = @"0";

@implementation AMAStringDatabaseKeyValueStorageConverter

- (BOOL)boolForObject:(NSString *)object
{
    return [object isEqualToString:kAMATrueValue];
}

- (NSString *)objectForBool:(BOOL)value
{
    return value ? kAMATrueValue : kAMAFalseValue;
}

- (NSData *)dataForObject:(NSString *)object
{
    if (object == nil) {
        return nil;
    }
    return [[NSData alloc] initWithBase64EncodedString:object options:0];
}

- (NSString *)objectForData:(NSData *)value
{
    return [value base64EncodedStringWithOptions:0];
}

- (NSDate *)dateForObject:(NSString *)object
{
    if (object.length == 0) {
        return nil;
    }
    return [NSDate dateWithTimeIntervalSince1970:[self doubleForObject:object]];
}

- (NSString *)objectForDate:(NSDate *)value
{
    return [self objectForDouble:value.timeIntervalSince1970];
}

- (double)doubleForObject:(NSString *)object
{
    return object.doubleValue;
}

- (NSString *)objectForDouble:(double)value
{
    return [NSString stringWithFormat:@"%f", value];
}

- (long long)longLongForObject:(NSString *)object
{
    return object.longLongValue;
}

- (NSString *)objectForLongLong:(long long)value
{
    return [NSString stringWithFormat:@"%lld", value];
}

- (unsigned long long)unsignedLongLongForObject:(NSString *)object
{
    uint64_t value = 0;
    NSString *error = nil;
    
    if (object != nil) {
        char *endptr = NULL;
        const char *const str = [object UTF8String];
        
        errno = 0;
        value = (uint64_t)strtoull(str, &endptr, 10);
        
        if (endptr == str) {
            error = [NSString stringWithFormat:@"%@ not a decimal number", object];
        }
        else if ('\0' != *endptr) {
            error = [NSString stringWithFormat:@"%@ extra characters at end of input: %s", object, endptr];
        }
        else if (ULLONG_MAX == value && ERANGE == errno) {
            error = [NSString stringWithFormat:@"%@ out of range of type unsigned long long", object];
        }
    }
    else {
        error = @"nil passed";
    }

    if (error != nil) {
        AMALogAssert(@"%@", error);
        return 0;
    }

    return value;
}

- (NSString *)objectForUnsignedLongLong:(unsigned long long)value
{
    return [NSString stringWithFormat:@"%llu", value];
}

- (NSString *)stringForObject:(NSString *)object
{
    return [object copy];
}

- (NSString *)objectForString:(NSString *)value
{
    return value;
}

@end
