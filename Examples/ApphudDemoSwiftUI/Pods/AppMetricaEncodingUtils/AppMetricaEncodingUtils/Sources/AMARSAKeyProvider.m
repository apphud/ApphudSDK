
#import <AppMetricaEncodingUtils/AppMetricaEncodingUtils.h>

@interface AMARSAKeyProvider ()

@property (nonatomic, strong, readonly) AMARSAKey *key;
@property (nonatomic, strong, readonly) NSLock *lock;

@end

@implementation AMARSAKeyProvider

- (instancetype)initWithKey:(AMARSAKey *)key
{
    self = [super init];
    if (self != nil) {
        _key = key;
        _lock = [[NSLock alloc] init];
    }
    return self;
}

- (SecKeyRef)keyWithStatus:(OSStatus *)status
{
    [self.lock lock];
    SecKeyRef keyRef = NULL;
    OSStatus internalStatus = noErr;

    if (@available(iOS 10.0, tvOS 10.0, *)) {
        keyRef = [self createKey];
    }

    if (keyRef == NULL) {
        internalStatus = [self fetchExistingKey:&keyRef];
        if (internalStatus != noErr) {
            internalStatus = [self fetchResavedKey:&keyRef];
        }
    }

    if (status != NULL) {
        *status = internalStatus;
    }

    [self.lock unlock];
    return keyRef;
}

- (SecKeyRef)createKey API_AVAILABLE(ios(10.0), tvos(10.0))
{
    CFErrorRef error = NULL;
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
    attributes[(__bridge id)kSecAttrKeyType] = (__bridge id)kSecAttrKeyTypeRSA;
    attributes[(__bridge id)kSecAttrKeyClass] = (__bridge id)[self keyType];
    return SecKeyCreateWithData((__bridge CFDataRef)self.key.data, (__bridge CFDictionaryRef)attributes, &error);
}

- (OSStatus)fetchExistingKey:(SecKeyRef *)keyRef
{
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    query[(__bridge id)kSecClass] = (__bridge id)kSecClassKey;
    query[(__bridge id)kSecAttrKeyType] = (__bridge id)kSecAttrKeyTypeRSA;
    query[(__bridge id)kSecAttrApplicationTag] = [self.key.uniqueTag dataUsingEncoding:NSUTF8StringEncoding];
    query[(__bridge id)kSecAttrKeyClass] = (__bridge id)[self keyType];
    query[(__bridge id)kSecReturnRef] = @YES;
    return SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)keyRef);
}

- (OSStatus)saveKey
{
    // Delete any old lingering key with the same tag
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    query[(__bridge id)kSecClass] = (__bridge id)kSecClassKey;
    query[(__bridge id)kSecAttrKeyType] = (__bridge id)kSecAttrKeyTypeRSA;
    query[(__bridge id)kSecAttrApplicationTag] = [self.key.uniqueTag dataUsingEncoding:NSUTF8StringEncoding];
    SecItemDelete((__bridge CFDictionaryRef)query);

    // Add persistent version of the key to system keychain
    query[(__bridge id)kSecValueData] = self.key.data;
    query[(__bridge id)kSecAttrKeyClass] = (__bridge id)[self keyType];
    query[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlock;
    query[(__bridge id)kSecReturnPersistentRef] = @YES;

    CFTypeRef persistKey = nil;
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)query, &persistKey);
    if (persistKey != nil) {
        CFRelease(persistKey);
    }
    return status;
}

- (OSStatus)fetchResavedKey:(SecKeyRef *)keyRef
{
    OSStatus status = [self saveKey];
    if ((status == noErr) || (status == errSecDuplicateItem)) {
        status = [self fetchExistingKey:keyRef];
    }
    return status;
}

- (CFStringRef)keyType
{
    switch (self.key.keyType) {
        case AMARSAKeyTypePublic:
            return kSecAttrKeyClassPublic;

        case AMARSAKeyTypePrivate:
            return kSecAttrKeyClassPrivate;
    }
}

+ (instancetype)sharedInstanceForKey:(AMARSAKey *)key
{
    static NSMutableDictionary *instances = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instances = [NSMutableDictionary dictionary];
    });

    AMARSAKeyProvider *instance = nil;
    @synchronized ([self class]) {
        instance = instances[key];
        if (instance == nil) {
            instance = [[AMARSAKeyProvider alloc] initWithKey:key];
            instances[key] = instance;
        }
    }
    return instance;
}

@end
