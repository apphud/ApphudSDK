
#import <Foundation/Foundation.h>

NS_SWIFT_NAME(ValidationUtilities)
@interface AMAValidationUtilities : NSObject

+ (BOOL)validateISO4217Currency:(NSString *)currency;

+ (BOOL)validateJSONDictionary:(NSDictionary *)dictionary
                    valueClass:(Class)valueClass
       valueStructureValidator:(BOOL (^)(id))validator;

+ (BOOL)validateJSONArray:(NSArray *)array
               valueClass:(Class)valueClass;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end
