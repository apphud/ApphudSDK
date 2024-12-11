
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(StackTraceElement)
@interface AMAStackTraceElement : NSObject

/**
 Name of the class/interface/symbol (depending on the plugin you are using) where the error occurred.
 The maximum length is 100 characters.
 If the value exceeds the limit, AppMetrica truncates it.
 */
@property (nonatomic, copy, nullable) NSString *className;
/**
 Name of the file where the error occurred.
 The maximum length is 100 characters.
 If the value exceeds the limit, AppMetrica truncates it.
 */
@property (nonatomic, copy, nullable) NSString *fileName;
/**
 Line number in which the error occurred.
 */
@property (nonatomic, strong, nullable) NSNumber *line;
/**
 Column in which the error occurred.
 */
@property (nonatomic, strong, nullable) NSNumber *column;
/**
 Name of the method/function (depending on the plugin you are using) where the error occurred.
 The maximum length is 100 characters.
 If the value exceeds the limit, AppMetrica truncates it.
 */
@property (nonatomic, copy, nullable) NSString *methodName;

- (instancetype)init;
- (instancetype)initWithClassName:(nullable NSString *)className
                         fileName:(nullable NSString *)fileName
                             line:(nullable NSNumber *)line
                           column:(nullable NSNumber *)column
                       methodName:(nullable NSString *)methodName
NS_SWIFT_NAME(init(className:fileName:line:column:methodName:));

@end

NS_ASSUME_NONNULL_END
