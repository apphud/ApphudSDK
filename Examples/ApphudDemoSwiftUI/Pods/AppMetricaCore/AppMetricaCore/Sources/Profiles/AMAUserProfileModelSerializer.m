
#import "AMACore.h"
#import "AMAUserProfileModelSerializer.h"
#import "AMAUserProfileModel.h"
#import "AMAAttributeKey.h"
#import "AMAAttributeValue.h"
#import "Profile.pb-c.h"
#import <AppMetricaProtobufUtils/AppMetricaProtobufUtils.h>

@implementation AMAUserProfileModelSerializer

#pragma mark - Public -

- (NSData *)dataWithModel:(AMAUserProfileModel *)model
{
    NSData *__block packedProfile = nil;
    [AMAAllocationsTrackerProvider track:^(id<AMAAllocationsTracking> tracker) {
        Ama__Profile profile = AMA__PROFILE__INIT;
        NSUInteger attributesCount = model.attributes.count;
        profile.n_attributes = attributesCount;
        if (attributesCount > 0) {
            profile.attributes = [self serializedAttributes:model.attributes withTracker:tracker];
        }
        packedProfile = [self packProfile:&profile];
    }];

    return packedProfile;
}

#pragma mark - Private -

- (Ama__Profile__Attribute__Type)attributeTypeForModelType:(AMAAttributeType)modelType
{
    switch (modelType) {
        case AMAAttributeTypeString:
            return AMA__PROFILE__ATTRIBUTE__TYPE__STRING;

        case AMAAttributeTypeNumber:
            return AMA__PROFILE__ATTRIBUTE__TYPE__NUMBER;

        case AMAAttributeTypeCounter:
            return AMA__PROFILE__ATTRIBUTE__TYPE__COUNTER;

        case AMAAttributeTypeBool:
            return AMA__PROFILE__ATTRIBUTE__TYPE__BOOL;

        default:
            AMALogAssert(@"Unknown attribute type: %ud", (unsigned)modelType);
            return AMA__PROFILE__ATTRIBUTE__TYPE__STRING; // There is no UNKNOWN type
    }
}

- (Ama__Profile__AttributeMetaInfo *)attributeMetaInfoWithValue:(AMAAttributeValue *)model
                                                        tracker:(id<AMAAllocationsTracking>)tracker
{
    Ama__Profile__AttributeMetaInfo *metaInfo = [tracker allocateSize:sizeof(Ama__Profile__AttributeMetaInfo)];
    ama__profile__attribute_meta_info__init(metaInfo);

    BOOL hasStorePermanentlyModifier = model.setIfUndefined != nil;
    metaInfo->has_set_if_undefined = hasStorePermanentlyModifier;
    if (hasStorePermanentlyModifier) {
        metaInfo->set_if_undefined = model.setIfUndefined.boolValue;
    }

    BOOL hasResetModifier = model.reset != nil;
    metaInfo->has_reset = hasResetModifier;
    if (hasResetModifier) {
        metaInfo->reset = model.reset.boolValue;
    }

    return metaInfo;
}

- (Ama__Profile__AttributeValue *)attributeValueWithValue:(AMAAttributeValue *)model
                                                  tracker:(id<AMAAllocationsTracking>)tracker
{
    Ama__Profile__AttributeValue *attributeValue = [tracker allocateSize:sizeof(Ama__Profile__AttributeValue)];
    ama__profile__attribute_value__init(attributeValue);

    BOOL hasStringValue = model.stringValue != nil;
    attributeValue->has_string_value = hasStringValue;
    if (hasStringValue) {
        [AMAProtobufUtilities fillBinaryData:&attributeValue->string_value
                                  withString:model.stringValue
                                     tracker:tracker];
    }

    BOOL hasNumberValue = model.numberValue != nil;
    attributeValue->has_number_value = hasNumberValue;
    if (hasNumberValue) {
        attributeValue->number_value = model.numberValue.doubleValue;
    }

    BOOL hasCounterValue = model.counterValue != nil;
    attributeValue->has_counter_modification = hasCounterValue;
    if (hasCounterValue) {
        attributeValue->counter_modification = model.counterValue.doubleValue;
    }

    BOOL hasBoolValue = model.boolValue != nil;
    attributeValue->has_bool_value = hasBoolValue;
    if (hasBoolValue) {
        attributeValue->bool_value = model.boolValue.boolValue;
    }

    return attributeValue;
}

- (Ama__Profile__Attribute **)serializedAttributes:(NSDictionary *)customAttributes
                                       withTracker:(id<AMAAllocationsTracking>)tracker
{
    Ama__Profile__Attribute **attributes =
        [tracker allocateSize:sizeof(Ama__Profile__Attribute *) * customAttributes.count];

    NSUInteger __block index = 0;
    [customAttributes enumerateKeysAndObjectsUsingBlock:^(AMAAttributeKey *key, AMAAttributeValue *value, BOOL *stop) {
        Ama__Profile__Attribute *attribute = [tracker allocateSize:sizeof(Ama__Profile__Attribute)];
        ama__profile__attribute__init(attribute);

        [AMAProtobufUtilities fillBinaryData:&attribute->name withString:key.name tracker:tracker];
        attribute->type = [self attributeTypeForModelType:key.type];

        attribute->meta_info = [self attributeMetaInfoWithValue:value tracker:tracker];
        attribute->value = [self attributeValueWithValue:value tracker:tracker];

        attributes[index] = attribute;
        index += 1;
    }];
    return attributes;
}

- (NSData *)packProfile:(Ama__Profile *)profile
{
    size_t dataSize = ama__profile__get_packed_size(profile);
    void *buffer = malloc(dataSize);
    ama__profile__pack(profile, buffer);
    NSData *data = [NSData dataWithBytesNoCopy:buffer length:dataSize];
    return data;
}

@end
