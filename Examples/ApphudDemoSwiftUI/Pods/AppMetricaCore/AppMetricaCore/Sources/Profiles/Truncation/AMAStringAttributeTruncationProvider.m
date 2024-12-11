
#import "AMAStringAttributeTruncationProvider.h"
#import "AMAStringAttributeTruncator.h"

@interface AMAStringAttributeTruncationProvider ()

@property (nonatomic, strong) id<AMAStringTruncating> underlyingTruncator;

@end

@implementation AMAStringAttributeTruncationProvider

- (instancetype)initWithUnderlyingTruncator:(id<AMAStringTruncating>)underlyingTruncator
{
    self = [super init];
    if (self != nil) {
        _underlyingTruncator = underlyingTruncator;
    }
    return self;
}

- (id<AMAStringTruncating>)truncatorWithAttributeName:(NSString *)attributeName
{
    return [[AMAStringAttributeTruncator alloc] initWithAttributeName:attributeName
                                                  underlyingTruncator:self.underlyingTruncator];
}

@end
