
#import "AMANetworkCore.h"
#import <AppMetricaNetwork/AppMetricaNetwork.h>

@interface AMAHTTPSessionProvider ()

@property (nonatomic, strong, readonly) NSOperationQueue *callbackQueue;

@property (nonatomic, strong, readwrite) NSURLSession *session;

@end

@implementation AMAHTTPSessionProvider

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _callbackQueue = [[NSOperationQueue alloc] init];
        _callbackQueue.underlyingQueue = [AMAQueuesFactory serialQueueForIdentifierObject:self
                                                                                   domain:@"io.appmetrica.Network"];
        _callbackQueue.maxConcurrentOperationCount = 1;
    }
    return self;
}

- (NSURLSessionConfiguration *)configuration
{
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    configuration.timeoutIntervalForRequest = 60.0;
    configuration.URLCache = nil;
    return configuration;
}

- (NSURLSession *)session
{
    if (_session == nil) {
        @synchronized (self) {
            if (_session == nil) {
                _session = [NSURLSession sessionWithConfiguration:[self configuration]
                                                         delegate:self
                                                    delegateQueue:self.callbackQueue];
            }
        }
    }
    return _session;
}

+ (instancetype)sharedInstance
{
    static AMAHTTPSessionProvider *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[[self class] alloc] init];
    });
    return instance;
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error
{
    if (_session == session) {
        @synchronized (self) {
            if (_session == session) {
                _session = nil;
            }
        }
    }
}

@end
