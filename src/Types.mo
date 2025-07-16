/// Protobuf (Protocol Buffers) type definitions for Motoko.
///
/// This module defines the core types used throughout the Protobuf library.
/// Protocol Buffers uses a wire format with field numbers and wire types to
/// efficiently encode structured data.
///
/// Key concepts:
/// * Messages are collections of fields
/// * Fields have numbers, wire types, and values
/// * Wire types determine how values are encoded
/// * Field numbers allow schema evolution
///
/// Example usage:
/// ```motoko
/// // Define a simple message with two fields
/// let message : Message = [
///   { fieldNumber = 1; wireType = #varint; value = #int32(42) },
///   { fieldNumber = 2; wireType = #lengthDelimited; value = #string("hello") }
/// ];
/// ```
module {
    /// Represents a complete Protobuf message as an array of fields.
    /// Fields can appear in any order and duplicate field numbers are allowed
    /// (last value wins for singular fields, all values kept for repeated fields).
    ///
    /// Example:
    /// ```motoko
    /// let message : Message = [
    ///   { fieldNumber = 1; wireType = #varint; value = #int32(150) },
    ///   { fieldNumber = 2; wireType = #lengthDelimited; value = #string("test") },
    ///   { fieldNumber = 3; wireType = #fixed32; value = #float(3.14) }
    /// ];
    /// ```
    public type Message = [Field];

    /// Represents a single field within a Protobuf message.
    /// Each field consists of a field number (for schema identification),
    /// a wire type (encoding format), and the actual value.
    ///
    /// Field numbers:
    /// * Must be positive integers (1 to 2^29 - 1)
    /// * Numbers 1-15 use 1 byte for field+wiretype encoding
    /// * Numbers 16-2047 use 2 bytes for field+wiretype encoding
    /// * Numbers 19000-19999 are reserved by Protocol Buffers
    ///
    /// Example:
    /// ```motoko
    /// let field : Field = {
    ///   fieldNumber = 1;
    ///   wireType = #varint;
    ///   value = #int32(42)
    /// };
    /// ```
    public type Field = {
        /// The field number used in the schema definition (1 to 2^29 - 1)
        fieldNumber : Nat32;
        /// The wire type determining how the value is encoded
        wireType : WireType;
        /// The actual field value
        value : Value;
    };

    /// Represents the wire type of a Protobuf field.
    /// Wire types determine how values are encoded in the binary format.
    /// There are 6 wire types defined in the Protocol Buffers specification.
    ///
    /// Wire type usage:
    /// * varint: int32, int64, uint32, uint64, sint32, sint64, bool, enum
    /// * fixed64: fixed64, sfixed64, double
    /// * lengthDelimited: string, bytes, embedded messages, packed repeated fields
    /// * startGroup: deprecated group start (not supported)
    /// * endGroup: deprecated group end (not supported)
    /// * fixed32: fixed32, sfixed32, float
    ///
    /// Example:
    /// ```motoko
    /// let stringWireType : WireType = #lengthDelimited;
    /// let intWireType : WireType = #varint;
    /// let floatWireType : WireType = #fixed32;
    /// ```
    public type WireType = {
        /// Variable-length integers (0)
        /// Used for: int32, int64, uint32, uint64, sint32, sint64, bool, enum
        #varint;

        /// 64-bit fixed-length values (1)
        /// Used for: fixed64, sfixed64, double
        #fixed64;

        /// Length-delimited values (2)
        /// Used for: string, bytes, embedded messages, packed repeated fields
        #lengthDelimited;

        /// 32-bit fixed-length values (5)
        /// Used for: fixed32, sfixed32, float
        #fixed32;
    };

    /// Represents the value of a Protobuf field.
    /// The value type must be compatible with the specified wire type.
    /// Some values support multiple wire types (e.g., integers can use varint or fixed).
    ///
    /// Type compatibility:
    /// * varint wire type: int32, int64, uint32, uint64, sint32, sint64, bool
    /// * fixed32 wire type: fixed32, sfixed32, float
    /// * fixed64 wire type: fixed64, sfixed64, double
    /// * lengthDelimited wire type: string, bytes, message
    ///
    /// Example:
    /// ```motoko
    /// let intValue : Value = #int32(42);
    /// let stringValue : Value = #string("hello");
    /// let bytesValue : Value = #bytes([0x01, 0x02, 0x03]);
    /// let nestedMessage : Value = #message([
    ///   { fieldNumber = 1; wireType = #varint; value = #bool(true) }
    /// ]);
    /// ```
    public type Value = {
        /// 32-bit signed integer (can use varint or fixed32 wire type)
        #int32 : Int32;

        /// 64-bit signed integer (can use varint or fixed64 wire type)
        #int64 : Int64;

        /// 32-bit unsigned integer (can use varint or fixed32 wire type)
        #uint32 : Nat32;

        /// 64-bit unsigned integer (can use varint or fixed64 wire type)
        #uint64 : Nat64;

        /// 32-bit signed integer with zigzag encoding (varint wire type)
        #sint32 : Int32;

        /// 64-bit signed integer with zigzag encoding (varint wire type)
        #sint64 : Int64;

        /// 32-bit unsigned fixed integer (fixed32 wire type)
        #fixed32 : Nat32;

        /// 64-bit unsigned fixed integer (fixed64 wire type)
        #fixed64 : Nat64;

        /// 32-bit signed fixed integer (fixed32 wire type)
        #sfixed32 : Int32;

        /// 64-bit signed fixed integer (fixed64 wire type)
        #sfixed64 : Int64;

        /// Boolean value (varint wire type, 0 or 1)
        #bool : Bool;

        /// UTF-8 encoded string (lengthDelimited wire type)
        #string : Text;

        /// Raw byte array (lengthDelimited wire type)
        #bytes : [Nat8];

        /// 32-bit IEEE 754 floating point (fixed32 wire type)
        #float : Float;

        /// 64-bit IEEE 754 floating point (fixed64 wire type)
        #double : Float;

        /// Nested message (lengthDelimited wire type)
        #message : Message;
    };

    /// Represents errors that can occur during Protobuf encoding operations.
    /// These errors indicate problems with the input values or encoding process.
    ///
    /// Example usage:
    /// ```motoko
    /// let result = Protobuf.encode(message);
    /// switch (result) {
    ///   case (#ok(bytes)) { /* Use encoded bytes */ };
    ///   case (#err(#invalidFieldNumber)) { /* Handle invalid field number */ };
    ///   case (#err(#wireTypeMismatch(msg))) { /* Handle type mismatch */ };
    ///   case (#err(#invalidValue(msg))) { /* Handle invalid value */ };
    /// };
    /// ```
    public type EncodingError = {
        /// Field number is out of valid range (must be 1 to 2^29 - 1, excluding reserved ranges)
        #invalidFieldNumber;

        /// The value type doesn't match the specified wire type
        #wireTypeMismatch : Text;

        /// The value cannot be encoded (e.g., invalid UTF-8 in string)
        #invalidValue : Text;
    };

    /// Represents errors that can occur during Protobuf decoding operations.
    /// These errors indicate problems with the input data or decoding process.
    ///
    /// Example usage:
    /// ```motoko
    /// let result = Protobuf.decode(bytes);
    /// switch (result) {
    ///   case (#ok(message)) { /* Use decoded message */ };
    ///   case (#err(#unexpectedEndOfBytes)) { /* Handle truncated data */ };
    ///   case (#err(#invalidWireType(wt))) { /* Handle invalid wire type */ };
    ///   case (#err(#invalidVarint)) { /* Handle malformed varint */ };
    ///   case (#err(#invalidUtf8)) { /* Handle invalid UTF-8 */ };
    ///   case (#err(#invalidFieldNumber)) { /* Handle invalid field number */ };
    /// };
    /// ```
    public type DecodingError = {
        /// The input bytes ended unexpectedly while decoding was in progress
        #unexpectedEndOfBytes;

        /// Invalid wire type encountered (not 0, 1, 2, or 5)
        #invalidWireType : Nat8;

        /// Malformed varint encoding (too long or incomplete)
        #invalidVarint;

        /// Invalid UTF-8 encoding in string field
        #invalidUtf8;

        /// Field number is out of valid range or reserved
        #invalidFieldNumber;

        /// Length-delimited field has invalid length
        #invalidLength;

        /// General invalid format with descriptive message
        #invalidFormat : Text;
    };
};
