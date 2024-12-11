
#import "AMAAttributeUpdate.h"
#import "AMAAttributeValueUpdate.h"
#import "AMAAttributeKey.h"
#import "AMAAttributeValue.h"
#import "AMAUserProfileModel.h"

@implementation AMAAttributeUpdate

- (instancetype)initWithName:(NSString *)name
                        type:(AMAAttributeType)type
                      custom:(BOOL)custom
                 valueUpdate:(id<AMAAttributeValueUpdate>)valueUpdate
{
    self = [super init];
    if (self != nil) {
        _name = [name copy];
        _type = type;
        _custom = custom;
        _valueUpdate = valueUpdate;
    }
    return self;
}

#pragma mark - Public -

- (void)applyToModel:(AMAUserProfileModel *)model
{
    AMAAttributeKey *key = [[AMAAttributeKey alloc] initWithName:self.name type:self.type];
    NSMutableDictionary *attributes = [self attributesOfModel:model];
    AMAAttributeValue *value = attributes[key];
    if (value == nil) {
        value = [[AMAAttributeValue alloc] init];
        attributes[key] = value;
        if (self.custom) {
            model.customAttributeKeysCount += 1;
        }
    }
    [self.valueUpdate applyToValue:value];
}

#pragma mark - Private -

- (NSMutableDictionary *)attributesOfModel:(AMAUserProfileModel *)model
{
    NSMutableDictionary *attributes = model.attributes;
    if (attributes == nil) {
        attributes = [NSMutableDictionary dictionary];
        model.attributes = attributes;
    }
    return attributes;
}

@end
