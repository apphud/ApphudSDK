
#import <Foundation/Foundation.h>

extern NSString *const kAMASQLName;
extern NSString *const kAMASQLType;
extern NSString *const kAMASQLIsNotNull;
extern NSString *const kAMASQLIsPrimaryKey;
extern NSString *const kAMASQLIsAutoincrement;
extern NSString *const kAMASQLDefaultValue;

@interface AMATableDescriptionProvider : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (NSArray *)eventsTableMetaInfo;
+ (NSArray *)sessionsTableMetaInfo;
+ (NSArray *)locationsTableMetaInfo;
+ (NSArray *)visitsTableMetaInfo;
+ (NSArray *)stringKVTableMetaInfo;
+ (NSArray *)binaryKVTableMetaInfo;

@end
