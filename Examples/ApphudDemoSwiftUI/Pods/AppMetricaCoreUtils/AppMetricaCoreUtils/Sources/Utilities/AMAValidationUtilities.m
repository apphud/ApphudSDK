
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

@implementation AMAValidationUtilities

+ (BOOL)validateISO4217Currency:(NSString *)currency
{
    BOOL isValid = currency.length == 3;
    if (isValid) {
        NSCharacterSet *unwantedCharacters = [[NSCharacterSet uppercaseLetterCharacterSet] invertedSet];
        isValid = [currency rangeOfCharacterFromSet:unwantedCharacters].location == NSNotFound;
    }
    return isValid;
}

 + (BOOL)validateJSONDictionary:(NSDictionary *)dictionary
                     valueClass:(Class)valueClass
        valueStructureValidator:(BOOL (^)(id))validator
 {
     BOOL isValid = YES;
     for (NSString *dictKey in dictionary) {
         id obj = dictionary[dictKey];
         isValid = isValid && [dictKey isKindOfClass:NSString.class] && [obj isKindOfClass:valueClass];
         if (validator != nil) {
             isValid = isValid && validator(obj);
         }
     }
     return isValid;
 }

+ (BOOL)validateJSONArray:(NSArray *)array
               valueClass:(Class)valueClass
{
    for (id value in array) {
        if ([value isKindOfClass:valueClass] == NO) {
            return NO;
        }
    }
    return YES;
}

@end
