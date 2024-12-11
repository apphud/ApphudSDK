
#import "AMADispatchStrategy.h"
#import "AMAReporterStorage.h"
#import "AMAReportExecutionConditionChecker.h"
#import "AMAStartupController.h"

@interface AMADispatchStrategy ()

@property (nonatomic, strong, readwrite) AMAReporterStorage *storage;
@property (nonatomic, weak, readwrite) id<AMADispatchStrategyDelegate> delegate;
@property (nonatomic, strong, readonly) id<AMAReportExecutionConditionChecker> executionConditionChecker;

@end

@implementation AMADispatchStrategy

- (instancetype)initWithDelegate:(id<AMADispatchStrategyDelegate>)delegate
                         storage:(AMAReporterStorage *)storage
       executionConditionChecker:(id<AMAReportExecutionConditionChecker>)executionConditionChecker
{
    self = [super init];
    if (self != nil) {
        _delegate = delegate;
        _storage = storage;
        _executionConditionChecker = executionConditionChecker;
    }
    return self;
}

- (void)dealloc
{
    _delegate = nil;
}

- (void)start
{
}

- (void)shutdown
{
}

- (void)triggerDispatch
{
    [self.delegate dispatchStrategyWantsReportingToHappen:self];
}

- (void)restart
{
    [self shutdown];
    [self start];
}

- (BOOL)canBeExecuted:(AMAStartupController *)startupController
{
    return [self.executionConditionChecker canBeExecuted:startupController];
}

- (BOOL)isEqual:(AMADispatchStrategy *)other
{
    if (other == self) {
        return YES;
    }
    if (other == nil || [[self class] isMemberOfClass:[other class]] == NO) {
        return NO;
    }
    if (self.storage.apiKey != other.storage.apiKey && [self.storage.apiKey isEqual:other.storage.apiKey] == NO) {
        return NO;
    }

    return YES;
}

- (NSUInteger)hash
{
    return [self.storage.apiKey hash];
}

#if AMA_ALLOW_DESCRIPTIONS
- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ apiKey=%@>", super.description, self.storage.apiKey];
}
#endif

@end
