
#import <AppMetricaProtobufUtils/AppMetricaProtobufUtils.h>

@interface AMAProtobufAllocator ()

@property (nonatomic, strong, readonly) id<AMAAllocationsTracking> tracker;
@property (nonatomic, assign, readonly) ProtobufCAllocator *allocator;

- (void *)allocWithSize:(size_t)size;
- (void)free;

@end

static void *AMAProtobufAllocatorAlloc(void *allocator_data, size_t size)
{
    AMAProtobufAllocator *allocator = (__bridge AMAProtobufAllocator *)(allocator_data);
    return [allocator allocWithSize:size];
}

static void AMAProtobufAllocatorFree(void *allocator_data, void *pointer)
{
    AMAProtobufAllocator *allocator = (__bridge AMAProtobufAllocator *)(allocator_data);
    [allocator free];
}

@implementation AMAProtobufAllocator

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _tracker = [AMAAllocationsTrackerProvider manuallyHandledTracker];

        _allocator = [_tracker allocateSize:sizeof(ProtobufCAllocator)];
        _allocator->alloc = AMAProtobufAllocatorAlloc;
        _allocator->free = AMAProtobufAllocatorFree;
        _allocator->allocator_data = (__bridge void *)(self);
    }
    return self;
}

#pragma mark - Public

- (ProtobufCAllocator *)protobufCAllocator
{
    return self.allocator;
}

#pragma mark - Private

- (void *)allocWithSize:(size_t)size
{
    return [self.tracker allocateSize:size];
}

- (void)free
{
    // Do nothing, memory deallocates with deallocation of this object
}

@end
