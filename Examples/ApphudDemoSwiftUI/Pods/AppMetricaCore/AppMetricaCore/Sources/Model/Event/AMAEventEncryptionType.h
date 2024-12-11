
typedef NS_ENUM(NSUInteger, AMAEventEncryptionType) {
    // Payload is not encrypted.
    AMAEventEncryptionTypeNoEncryption = 1,

    // Payload is encrypted with AES and should be sent decrypted.
    // Encryption key is (hex)eb453eb231b240b6b1b0a7d1b678a546, iv is md5(bundleID ?: "io.appmetrica").
    AMAEventEncryptionTypeAESv1 = 2,

    // Payload is not encrypted, but compressed with GZip.
    AMAEventEncryptionTypeGZip = 3,
};

