
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Request)
@protocol AMARequest <NSObject>

@property (nonatomic, nullable, strong, readwrite) NSString *host;

@property (nonatomic, nullable, strong, readonly) NSData *body;
@property (nonatomic, nullable, strong, readonly) NSDictionary *headerComponents;
@property (nonatomic, nullable, strong, readonly) NSArray *pathComponents;
@property (nonatomic, nullable, strong, readonly) NSDictionary *GETParameters;

- (NSURLRequest *)buildURLRequest;

@end

NS_ASSUME_NONNULL_END
