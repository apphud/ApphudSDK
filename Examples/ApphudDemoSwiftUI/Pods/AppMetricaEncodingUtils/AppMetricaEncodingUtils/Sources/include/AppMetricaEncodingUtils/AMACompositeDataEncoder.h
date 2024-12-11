
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

/// A class for composite data encoding and decoding.
///
/// The `AMACompositeDataEncoder` class is responsible for composite data encoding and decoding using an array of
/// encoders conforming to the `AMADataEncoding` protocol.
///
/// - Encoding: Encoders are applied in the order they appear in the array.
/// - Decoding: Encoders are applied in reverse order.
///
/// Initialization with the standard `init` method is unavailable. Use `-initWithEncoders` instead.
///
/// Example usage:
/// ```objc
/// NSArray<id<AMADataEncoding>> *encoders = ... // Your encoders
/// AMACompositeDataEncoder *encoder = [[AMACompositeDataEncoder alloc] initWithEncoders:encoders];
/// NSData *encodedData = [encoder encodeData:originalData error:&error]; // Encodes in order
/// NSData *decodedData = [encoder decodeData:encodedData error:&error]; // Decodes in reverse order
///
NS_SWIFT_NAME(CompositeDataEncoder)
@interface AMACompositeDataEncoder : NSObject <AMADataEncoding>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/// Initializes the receiver with an array of objects conforming to the `AMADataEncoding` protocol.
///
/// - Parameter encoders: An array of objects that conform to `AMADataEncoding`. The order of the encoders
/// defines the encoding process, while decoding is performed in reverse order.
/// - Returns: A newly initialized `AMACompositeDataEncoder` instance.
///
- (instancetype)initWithEncoders:(NSArray<id<AMADataEncoding>> *)encoders;

@end
