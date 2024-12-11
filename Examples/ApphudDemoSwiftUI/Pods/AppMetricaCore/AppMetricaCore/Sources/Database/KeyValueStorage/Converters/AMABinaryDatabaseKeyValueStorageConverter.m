
#import "AMACore.h"
#import "AMABinaryDatabaseKeyValueStorageConverter.h"

@implementation AMABinaryDatabaseKeyValueStorageConverter

- (BOOL)boolForObject:(NSData *)object
{
    if (object.length != sizeof(uint8_t)) {
        AMALogError(@"Invalid data for 'uint8_t': %@", object);
        return NO;
    }
    return (*((uint8_t *)object.bytes)) != 0;
}

- (NSData *)objectForBool:(BOOL)value
{
    int8_t byte = (int8_t)(value ? 1 : 0);
    return [NSData dataWithBytes:&byte length:sizeof(int8_t)];
}

- (NSData *)dataForObject:(NSData *)object
{
    return [object copy];
}

- (NSData *)objectForData:(NSData *)value
{
    return value;
}

- (NSDate *)dateForObject:(NSData *)object
{
    if (object.length != sizeof(double)) {
        AMALogError(@"Invalid data for 'NSDate': %@", object);
        return nil;
    }
    return [NSDate dateWithTimeIntervalSinceReferenceDate:[self doubleForObject:object]];
}

- (NSData *)objectForDate:(NSDate *)value
{
    return [self objectForDouble:value.timeIntervalSinceReferenceDate];
}

- (double)doubleForObject:(NSData *)object
{
    if (object.length != sizeof(double)) {
        AMALogError(@"Invalid data for 'double': %@", object);
        return 0.0;
    }
    return *((double *)object.bytes);
}

- (NSData *)objectForDouble:(double)value
{
    return [NSData dataWithBytes:&value length:sizeof(value)];
}

- (long long)longLongForObject:(NSData *)object
{
    if (object.length != sizeof(long long)) {
        AMALogError(@"Invalid data for 'long long': %@", object);
        return 0;
    }
    return *((long long *)object.bytes);
}

- (NSData *)objectForLongLong:(long long)value
{
    return [NSData dataWithBytes:&value length:sizeof(long long)];
}

- (unsigned long long)unsignedLongLongForObject:(NSData *)object
{
    if (object.length != sizeof(unsigned long long)) {
        AMALogError(@"Invalid data for 'unsigned long long': %@", object);
        return 0;
    }
    return *((unsigned long long *)object.bytes);
}

- (NSData *)objectForUnsignedLongLong:(unsigned long long)value
{
    return [NSData dataWithBytes:&value length:sizeof(unsigned long long)];
}

- (NSString *)stringForObject:(NSData *)object
{
    if (object == nil) {
        return nil;
    }
    return [[NSString alloc] initWithData:object encoding:NSUTF8StringEncoding];
}

- (NSData *)objectForString:(NSString *)value
{
    return [value dataUsingEncoding:NSUTF8StringEncoding];
}

@end
