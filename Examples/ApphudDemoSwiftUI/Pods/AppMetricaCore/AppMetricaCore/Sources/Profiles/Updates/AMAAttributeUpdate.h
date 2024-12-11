
#import <Foundation/Foundation.h>
#import "AMAAttributeType.h"

@class AMAUserProfileModel;
@protocol AMAAttributeValueUpdate;

@interface AMAAttributeUpdate : NSObject

@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, assign, readonly) AMAAttributeType type;
@property (nonatomic, assign, readonly) BOOL custom;
@property (nonatomic, strong, readonly) id<AMAAttributeValueUpdate> valueUpdate;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithName:(NSString *)name
                        type:(AMAAttributeType)type
                      custom:(BOOL)custom
                 valueUpdate:(id<AMAAttributeValueUpdate>)valueUpdate;

- (void)applyToModel:(AMAUserProfileModel *)model;

@end
