
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

@interface  AMAArrayIterator ()

@property (nonatomic, copy) NSArray *items;
@property (nonatomic, strong) id current;
@property (nonatomic, assign) NSUInteger currentIndex;

@end

@implementation AMAArrayIterator

- (instancetype)initWithArray:(NSArray *)array
{
    self = [super init];
    if (self != nil) {
        _items = [array copy];
        _current = array.firstObject;
        _currentIndex = 0;
    }
    return self;
}

- (id)next
{
    id current = nil;

    @synchronized (self) {
        if (self.currentIndex + 1 < self.items.count) {
            self.currentIndex ++;
            current = self.items[self.currentIndex];
        }

        self.current = current;
    }

    return current;
}

- (void)reset
{
    @synchronized (self) {
        self.currentIndex = 0;
        self.current = self.items.firstObject;
    }
}

@end
