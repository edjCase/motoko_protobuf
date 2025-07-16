import Types "Types";
import Encoder "Encoder";
import Decoder "Decoder";

/// Protobuf (Protocol Buffers) library for Motoko.
///
/// This module provides functionality for encoding and decoding Protobuf data according to
/// Protocol Buffers Language Guide (proto3). Protocol Buffers is a language-neutral,
/// platform-neutral extensible mechanism for serializing structured data.
///
/// Key features:
/// * Encode Motoko values to Protobuf binary format
/// * Decode Protobuf binary data to Motoko values
/// * Support for all Protobuf wire types (varint, fixed64, length-delimited, fixed32)
/// * Efficient streaming encoding/decoding
/// * Field number and type tracking
///
/// Example usage:
/// ```motoko
/// import Protobuf "mo:protobuf";
/// import Result "mo:base/Result";
///
/// // Encode a message with fields
/// let message : Protobuf.Message = [
///   { fieldNumber = 1; wireType = #varint; value = #int32(150) },
///   { fieldNumber = 2; wireType = #lengthDelimited; value = #string("test") }
/// ];
/// let result = Protobuf.encode(message);
///
/// // Decode Protobuf bytes back to message
/// let bytes : [Nat8] = [0x08, 0x96, 0x01, 0x12, 0x04, 0x74, 0x65, 0x73, 0x74];
/// let decoded = Protobuf.decode(bytes.vals());
/// ```
///
/// Security considerations:
/// * Protobuf data from untrusted sources should be validated
/// * Be aware of potential memory usage with large messages
/// * Consider limits on recursion depth for deeply nested structures
module {
    /// Represents a Protobuf message as an array of fields.
    /// Each field contains a field number, wire type, and value.
    public type Message = Types.Message;

    /// Represents a single field in a Protobuf message.
    /// Contains field number, wire type, and the actual value.
    public type Field = Types.Field;

    /// Represents the wire type of a Protobuf field.
    /// Determines how the value is encoded on the wire.
    public type WireType = Types.WireType;

    /// Represents the value of a Protobuf field.
    /// The value type corresponds to the wire type.
    public type Value = Types.Value;

    /// Represents errors that can occur during Protobuf encoding operations.
    public type EncodingError = Types.EncodingError;

    /// Represents errors that can occur during Protobuf decoding operations.
    public type DecodingError = Types.DecodingError;

    /// Encodes a Protobuf message into binary format.
    /// This function converts a Motoko Protobuf message into its binary representation.
    ///
    /// Parameters:
    /// * `message`: The Protobuf message to encode
    ///
    /// Returns:
    /// * `#ok([Nat8])`: Successfully encoded bytes
    /// * `#err(EncodingError)`: Encoding failed with error details
    ///
    /// Example:
    /// ```motoko
    /// let message : Message = [
    ///   { fieldNumber = 1; wireType = #varint; value = #int32(150) }
    /// ];
    /// let result = encode(message);
    /// ```
    public let encode = Encoder.encode;

    /// Encodes a Protobuf message into a provided buffer and returns the number of bytes written.
    /// This function is more efficient than `encode` when you need to control the buffer
    /// or when encoding multiple messages sequentially.
    ///
    /// Parameters:
    /// * `buffer`: The buffer to append encoded bytes to
    /// * `message`: The Protobuf message to encode
    ///
    /// Returns:
    /// * `#ok(Nat)`: Successfully encoded, returns number of bytes written
    /// * `#err(EncodingError)`: Encoding failed with error details
    ///
    /// Example:
    /// ```motoko
    /// let buffer = Buffer.Buffer<Nat8>(100);
    /// let message : Message = [
    ///   { fieldNumber = 1; wireType = #varint; value = #int32(150) }
    /// ];
    /// let result = encodeToBuffer(buffer, message);
    /// ```
    public let encodeToBuffer = Encoder.encodeToBuffer;

    /// Decodes Protobuf binary data into a structured message.
    /// This function converts Protobuf bytes into a Motoko message representation.
    ///
    /// Parameters:
    /// * `bytes`: An iterator over the Protobuf-encoded bytes to decode
    ///
    /// Returns:
    /// * `#ok(Message)`: Successfully decoded Protobuf message
    /// * `#err(DecodingError)`: Decoding failed with error details
    ///
    /// Example:
    /// ```motoko
    /// let bytes: [Nat8] = [0x08, 0x96, 0x01]; // field 1, varint 150
    /// let result = decode(bytes.vals());
    /// ```
    public let decode = Decoder.decode;

    /// Encodes a single Protobuf field into binary format.
    /// This is a lower-level function for encoding individual fields.
    ///
    /// Parameters:
    /// * `field`: The field to encode
    ///
    /// Returns:
    /// * `#ok([Nat8])`: Successfully encoded field bytes
    /// * `#err(EncodingError)`: Encoding failed with error details
    ///
    /// Example:
    /// ```motoko
    /// let field : Field = { fieldNumber = 1; wireType = #varint; value = #int32(150) };
    /// let result = encodeField(field);
    /// ```
    public let encodeField = Encoder.encodeField;

    /// Encodes a single Protobuf field into a provided buffer.
    /// This is a lower-level function for encoding individual fields with buffer control.
    ///
    /// Parameters:
    /// * `buffer`: The buffer to append encoded bytes to
    /// * `field`: The field to encode
    ///
    /// Returns:
    /// * `#ok(Nat)`: Successfully encoded, returns number of bytes written
    /// * `#err(EncodingError)`: Encoding failed with error details
    ///
    /// Example:
    /// ```motoko
    /// let buffer = Buffer.Buffer<Nat8>(10);
    /// let field : Field = { fieldNumber = 1; wireType = #varint; value = #int32(150) };
    /// let result = encodeFieldToBuffer(buffer, field);
    /// ```
    public let encodeFieldToBuffer = Encoder.encodeFieldToBuffer;
};
