
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString *const AMAUserDefaultsStringKey NS_TYPED_ENUM;

extern AMAUserDefaultsStringKey kAMAUserDefaultsStringKeyPreviousBundleVersion;
extern AMAUserDefaultsStringKey kAMAUserDefaultsStringKeyPreviousOSVersion;
extern AMAUserDefaultsStringKey kAMAUserDefaultsStringKeyAppWasTerminated;
extern AMAUserDefaultsStringKey kAMAUserDefaultsStringKeyAppWasInBackground;

NS_SWIFT_NAME(UserDefaultsStorage)
@interface AMAUserDefaultsStorage : NSObject

- (void)setObject:(id)object forKey:(id)key;
- (void)setBool:(BOOL)flag forKey:(id)key;

- (NSString *)stringForKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key;

- (void)synchronize;

@end

NS_ASSUME_NONNULL_END
