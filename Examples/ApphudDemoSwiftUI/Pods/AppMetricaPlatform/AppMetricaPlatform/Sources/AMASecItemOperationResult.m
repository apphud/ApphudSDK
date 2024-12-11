
#import "AMASecItemOperationResult.h"

@interface AMASecItemOperationResult ()

@property (nonatomic, assign) OSStatus status;
@property (nonatomic, copy) NSDictionary *attributes;

@end

@implementation AMASecItemOperationResult

- (instancetype)initWithStatus:(OSStatus)status attributes:(NSDictionary *)attributes
{
    self = [super init];
    if (self != nil) {
        self.status = status;
        self.attributes = attributes;
    }
    return self;
}

@end
