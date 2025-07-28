/// Type definitions for Protocol Buffer data structures.
///
/// This module defines all the core types used for representing protobuf
/// messages, fields, values, and wire format information in Motoko.
module {
  /// Wire format types used in protobuf encoding.
  /// Determines how data is serialized at the byte level.
  public type WireType = {
    #varint; // Variable-length integers (int32, int64, uint32, uint64, sint32, sint64, bool, enum)
    #fixed64; // Fixed 8-byte values (fixed64, sfixed64, double)
    #lengthDelimited; // Length-prefixed data (string, bytes, embedded messages, packed repeated fields)
    #fixed32; // Fixed 4-byte values (fixed32, sfixed32, float)
  };

  /// A protobuf field with number and typed value.
  /// Represents a complete field in a protobuf message.
  public type Field = {
    fieldNumber : Nat; // Field identifier (1 to 2^29-1)
    value : Value; // The actual field data
  };

  /// A raw protobuf field before type interpretation.
  /// Contains wire format information and raw bytes.
  public type RawField = {
    fieldNumber : Nat; // Field identifier
    wireType : WireType; // How the data is encoded
    value : [Nat8]; // Raw byte data
  };

  /// Schema definition for a protobuf field type.
  /// Used to validate and interpret raw field data.
  public type FieldType = {
    fieldNumber : Nat; // Field identifier
    valueType : ValueType; // Expected value type
  };

  /// Variable-length integer values.
  /// Encoded using LEB128 varint format.
  public type VarintValue = {
    #int32 : Int32; // 32-bit signed integer
    #int64 : Int64; // 64-bit signed integer
    #uint32 : Nat32; // 32-bit unsigned integer
    #uint64 : Nat64; // 64-bit unsigned integer
    #sint32 : Int32; // 32-bit zigzag-encoded signed integer
    #sint64 : Int64; // 64-bit zigzag-encoded signed integer
    #bool : Bool; // Boolean value (0 or 1)
    #enum : Int32; // Enumeration value
  };

  /// Fixed 32-bit values.
  /// Encoded as exactly 4 bytes in little-endian format.
  public type Fixed32Value = {
    #fixed32 : Nat32; // 32-bit unsigned integer
    #sfixed32 : Int32; // 32-bit signed integer
    #float : Float; // IEEE 754 single-precision float
  };

  /// Fixed 64-bit values.
  /// Encoded as exactly 8 bytes in little-endian format.
  public type Fixed64Value = {
    #fixed64 : Nat64; // 64-bit unsigned integer
    #sfixed64 : Int64; // 64-bit signed integer
    #double : Float; // IEEE 754 double-precision float
  };

  /// Values that are self-contained (don't reference other data).
  /// Can be encoded without additional length information.
  public type SelfContainedValue = VarintValue or Fixed32Value or Fixed64Value;

  /// Values that require length-delimited encoding.
  /// Need additional structure or length information.
  public type NotSelfContainedValue = {
    #string : Text; // UTF-8 encoded text
    #bytes : [Nat8]; // Raw byte array
    #message : [Field]; // Nested protobuf message
    #repeated : [Value]; // Array of values (packed or unpacked)
    #map : [(Value, Value)]; // Key-value pairs
  };

  /// All possible protobuf field values.
  ///
  /// This is the primary type for representing actual data in protobuf fields.
  /// It encompasses all supported protobuf data types, from simple primitives
  /// like integers and booleans to complex structures like nested messages
  /// and key-value maps.
  ///
  /// The type is divided into two categories:
  /// - Self-contained values: Can be encoded directly without additional metadata
  /// - Non-self-contained values: Require length prefixes or structural information
  ///
  /// Examples of each category:
  /// - Self-contained: `#int32(42)`, `#bool(true)`, `#float(3.14)`
  /// - Non-self-contained: `#string("hello")`, `#message([...])`, `#repeated([...])`
  ///
  /// This type is used when constructing protobuf messages for encoding
  /// and is returned when decoding protobuf binary data.
  public type Value = SelfContainedValue or NotSelfContainedValue;

  /// Type indicators for varint values.
  /// Used in schema definitions.
  public type VarintValueType = {
    #int32;
    #int64;
    #uint32;
    #uint64;
    #sint32;
    #sint64;
    #bool;
    #enum;
  };

  /// Type indicators for fixed 32-bit values.
  /// Used in schema definitions.
  public type Fixed32ValueType = {
    #fixed32;
    #sfixed32;
    #float;
  };

  /// Type indicators for fixed 64-bit values.
  /// Used in schema definitions.
  public type Fixed64ValueType = {
    #fixed64;
    #sfixed64;
    #double;
  };

  /// Type indicators for self-contained values.
  /// Union of varint, fixed32, and fixed64 type indicators.
  public type SelfContainedValueType = VarintValueType or Fixed32ValueType or Fixed64ValueType;

  /// Type indicators for non-self-contained values.
  /// Used in schema definitions for complex data types.
  public type NotSelfContainedValueType = {
    #string; // UTF-8 text
    #bytes; // Raw byte data
    #message : [FieldType]; // Nested message schema
    #repeated : ValueType; // Array element type
    #map : (ValueType, ValueType); // Key and value types
  };

  /// All possible protobuf value type indicators.
  ///
  /// This is the primary type used in schema definitions to specify what kind
  /// of data is expected in each protobuf field. It serves as a contract between
  /// the encoder and decoder, ensuring data is interpreted correctly.
  ///
  /// The type mirrors the structure of `Value` but focuses on type specification
  /// rather than actual data. It's essential for:
  /// - Validating incoming protobuf data during decoding
  /// - Determining the correct wire format for encoding
  /// - Providing type safety when working with protobuf messages
  ///
  /// Schema examples:
  /// ```motoko
  /// let userSchema = [
  ///   { fieldNumber = 1; valueType = #string },        // name
  ///   { fieldNumber = 2; valueType = #uint32 },        // age
  ///   { fieldNumber = 3; valueType = #repeated(#string) }, // hobbies
  ///   { fieldNumber = 4; valueType = #message(addressSchema) } // address
  /// ];
  /// ```
  ///
  /// The decoder uses this schema to convert raw protobuf bytes into properly
  /// typed `Value` instances, while the encoder uses it for validation.
  public type ValueType = SelfContainedValueType or NotSelfContainedValueType;

};
