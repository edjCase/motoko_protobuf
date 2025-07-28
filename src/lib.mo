import Types "Types";
import Encoder "Encoder";
import Decoder "Decoder";

/// A Motoko library for encoding and decoding Protocol Buffer (protobuf) messages.
/// This library provides functionality to serialize structured data into binary format
/// and deserialize it back to structured data following the protobuf specification.
module {

  /// Represents a protobuf field with an identifier, type information, and value.
  /// Used to define the structure and content of protobuf messages.
  public type Field = Types.Field;

  /// Defines the different data types that can be stored in protobuf fields.
  /// Includes primitive types like integers, strings, booleans, and complex types like messages and arrays.
  public type FieldType = Types.FieldType;

  /// Represents a raw protobuf field before type processing.
  /// Contains the basic wire format data including field number and raw value.
  public type RawField = Types.RawField;

  /// Defines the wire format types used in protobuf encoding.
  /// Determines how data is serialized at the byte level (varint, fixed32, fixed64, length-delimited).
  public type WireType = Types.WireType;

  /// Represents the actual data value stored in a protobuf field.
  /// Can contain various data types like numbers, text, bytes, or nested structures.
  public type Value = Types.Value;

  /// Defines the specific type of value stored in a protobuf field.
  /// Used for type checking and proper serialization/deserialization.
  public type ValueType = Types.ValueType;

  /// Encodes protobuf fields into a byte array.
  ///
  /// Takes an array of protobuf fields and serializes them into the standard
  /// protobuf binary format as a byte array.
  ///
  /// ```motoko
  /// let fields = [/* your protobuf fields */];
  /// let bytes = Protobuf.toBytes(fields);
  /// ```
  public let toBytes = Encoder.toBytes;

  /// Encodes protobuf fields into a byte buffer.
  ///
  /// Similar to toBytes but writes the serialized data into a provided buffer,
  /// allowing for more efficient memory management when building larger messages.
  ///
  /// ```motoko
  /// let buffer = Buffer.Buffer<Nat8>(0);
  /// let fields = [/* your protobuf fields */];
  /// Protobuf.toBytesBuffer(buffer, fields);
  /// ```
  public let toBytesBuffer = Encoder.toBytesBuffer;

  /// Decodes a byte array into protobuf fields.
  ///
  /// Parses protobuf binary data and converts it back into structured field data
  /// with proper type information and values.
  ///
  /// ```motoko
  /// let bytes : [Nat8] = [/* protobuf binary data */];
  /// switch (Protobuf.fromBytes(bytes)) {
  ///   case (#ok(fields)) { /* Successfully decoded fields */ };
  ///   case (#err(error)) { /* Decoding error */ };
  /// };
  /// ```
  public let fromBytes = Decoder.fromBytes;

  /// Decodes raw protobuf bytes into unprocessed field data.
  ///
  /// Performs basic parsing of protobuf wire format without applying type
  /// information, returning raw field data that can be further processed.
  ///
  /// ```motoko
  /// let bytes : [Nat8] = [/* protobuf binary data */];
  /// switch (Protobuf.fromRawBytes(bytes)) {
  ///   case (#ok(rawFields)) { /* Successfully decoded raw fields */ };
  ///   case (#err(error)) { /* Decoding error */ };
  /// };
  /// ```
  public let fromRawBytes = Decoder.fromRawBytes;

  /// Converts raw protobuf fields into typed fields.
  ///
  /// Takes raw field data (typically from fromRawBytes) and applies type
  /// information to create properly typed protobuf fields.
  ///
  /// ```motoko
  /// let rawFields = [/* raw field data */];
  /// switch (Protobuf.fromRawFields(rawFields)) {
  ///   case (#ok(fields)) { /* Successfully converted to typed fields */ };
  ///   case (#err(error)) { /* Conversion error */ };
  /// };
  /// ```
  public let fromRawFields = Decoder.fromRawFields;
};
