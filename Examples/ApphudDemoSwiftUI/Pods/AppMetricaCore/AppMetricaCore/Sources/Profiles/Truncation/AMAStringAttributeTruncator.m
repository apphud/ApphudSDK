
#import "AMAStringAttributeTruncator.h"
#import "AMAUserProfileLogger.h"

@interface AMAStringAttributeTruncator ()

@property (nonatomic, copy, readonly) NSString *attributeName;
@property (nonatomic, strong, readonly) id<AMAStringTruncating> underlyingTruncator;

@end

@implementation AMAStringAttributeTruncator

- (instancetype)initWithAttributeName:(NSString *)name
                  underlyingTruncator:(id<AMAStringTruncating>)underlyingTruncator
{
    self = [super init];
    if (self != nil) {
        _attributeName = [name copy];
        _underlyingTruncator = underlyingTruncator;
    }
    return self;
}

- (NSString *)truncatedString:(NSString *)string onTruncation:(AMATruncationBlock)onTruncation
{
    return [self.underlyingTruncator truncatedString:string onTruncation:^(NSUInteger bytesTruncated) {
        [AMAUserProfileLogger logStringAttributeValueTruncation:string attributeName:self.attributeName];
        if (onTruncation != nil) {
            onTruncation(bytesTruncated);
        }
    }];
}

@end
