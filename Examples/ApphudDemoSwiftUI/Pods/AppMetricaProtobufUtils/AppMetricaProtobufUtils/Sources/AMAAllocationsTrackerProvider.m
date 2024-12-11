
#import <AppMetricaProtobufUtils/AppMetricaProtobufUtils.h>

@interface AMAAllocationsTrackerProvider() <AMAAllocationsTracking>

@property (nonatomic, strong) NSPointerArray *tracker;

@end

@implementation AMAAllocationsTrackerProvider

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        self.tracker = [NSPointerArray pointerArrayWithOptions:NSPointerFunctionsMallocMemory |
            NSPointerFunctionsOpaquePersonality];
    }
    return self;
}

#pragma mark - Public

+ (void)track:(void (^)(id<AMAAllocationsTracking> tracker))block
{
    NS_VALID_UNTIL_END_OF_SCOPE AMAAllocationsTrackerProvider *tracker = [[AMAAllocationsTrackerProvider alloc] init];
    block((id)tracker);
}

+ (id<AMAAllocationsTracking>)manuallyHandledTracker
{
    return [[AMAAllocationsTrackerProvider alloc] init];
}

- (void *)allocateSize:(size_t)size
{
    void *ptr = malloc(size);
    [self trackPointer:ptr];
    return ptr;
}

#pragma mark - Private

- (BOOL)trackPointer:(const void *)pointer
{
    BOOL result = NO;
    if (pointer != NULL) {
        [self.tracker addPointer:(void *)pointer];
        result = YES;
    }
    return result;
}

@end
