
#import <Foundation/Foundation.h>

@interface AMAFramework : NSObject

@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly) NSString *path;
@property (nonatomic, assign, readonly) BOOL loaded;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithBundleAtPath:(NSString *)path;
- (Class)classFromString:(NSString *)string;
- (void *)functionFromString:(NSString *)string;
- (id)objectFromString:(NSString *)string;

@end
