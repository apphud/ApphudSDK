
#import "AMAEnvironmentTruncator.h"

@interface AMAEnvironmentTruncator()

@property (nonatomic, strong, readonly) id<AMAStringTruncating> parameterKeyTruncator;
@property (nonatomic, strong, readonly) id<AMAStringTruncating> parameterValueTruncator;
@property (nonatomic, assign, readonly) NSUInteger maxParametersCount;

@end

@implementation AMAEnvironmentTruncator

- (instancetype)init
{
    return [self initWithParameterKeyTruncator:[[AMALengthStringTruncator alloc] initWithMaxLength:100]
                       parameterValueTruncator:[[AMALengthStringTruncator alloc] initWithMaxLength:2000]
                            maxParametersCount:50];
}

- (instancetype)initWithParameterKeyTruncator:(id)parameterKeyTruncator
                      parameterValueTruncator:(id)parameterValueTruncator
                           maxParametersCount:(NSUInteger)maxParametersCount
{
    self = [super init];
    if (self != nil) {
        _parameterKeyTruncator = parameterKeyTruncator;
        _parameterValueTruncator = parameterValueTruncator;
        _maxParametersCount = maxParametersCount;
    }
    return self;
}

- (NSDictionary *)truncatedDictionary:(NSDictionary *)data onTruncation:(AMATruncationBlock)onTruncation
{
    if (data.count == 0) {
        return nil;
    }

    NSUInteger __block globalBytesTruncated = 0;
    NSUInteger __block parametersCount = 0;
    NSMutableDictionary *plainDictionary = [NSMutableDictionary dictionary];
    if (data.count > self.maxParametersCount) {
        size_t diff = data.count - self.maxParametersCount;
        AMALogWarn(@"Dictionary truncated by %zu pairs", diff);
        globalBytesTruncated += diff * sizeof(uintptr_t) * 2;
    }
    BOOL __block pairTruncated = NO;
    [data enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (parametersCount == self.maxParametersCount) {
            *stop = YES;
            return;
        }
        NSString *keyString =
            [self.parameterKeyTruncator truncatedString:[self stringForObject:key]
                                           onTruncation:^(NSUInteger bytesTruncated) {
                                               pairTruncated = YES;
                                               globalBytesTruncated += bytesTruncated;
                                           }];
        NSString *valueString =
            [self.parameterValueTruncator truncatedString:[self stringForObject:obj]
                                             onTruncation:^(NSUInteger bytesTruncated) {
                                                 pairTruncated = YES;
                                                 globalBytesTruncated += bytesTruncated;
                                             }];
        if (keyString != nil && valueString != nil) {
            plainDictionary[keyString] = valueString;
            ++parametersCount;
        }
    }];

    if (globalBytesTruncated != 0 && onTruncation != nil) {
        onTruncation(globalBytesTruncated);
    }

    if (pairTruncated) {
        AMALogWarn(@"Some pairs were truncated");
    }

    return [plainDictionary copy];
}

- (NSString *)stringForObject:(id)object
{
    if ([object isKindOfClass:[NSString class]]) {
        return object;
    }
    if ([object respondsToSelector:@selector(description)]) {
        return [object description];
    }
    return nil;
}

@end
