module {
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

    public type Field = {
        /// The field number in the Protobuf message.
        /// This is used to identify the field in the binary format.
        /// Field numbers must be positive integers.
        fieldNumber : Nat;

        /// The value of the field, represented as a `Value`.
        value : Value;
    };

    public type SchemalessField = {
        /// The field number in the Protobuf message.
        /// This is used to identify the field in the binary format.
        /// Field numbers must be positive integers.
        fieldNumber : Nat;

        /// The wire type of the field, indicating how the value is encoded.
        wireType : WireType;

        /// The raw value of the field, represented as a byte array.
        value : [Nat8];
    };

    public type FieldType = {
        fieldNumber : Nat;

        valueType : ValueType;
    };

    /// Represents the value of a Protobuf field.
    ///
    /// Example:
    /// ```motoko
    /// let intValue : Value = #int32(42);
    /// let stringValue : Value = #string("hello");
    /// let bytesValue : Value = #bytes([0x01, 0x02, 0x03]);
    /// ```
    public type Value = {
        #int32 : Int32;
        #int64 : Int64;
        #uint32 : Nat32;
        #uint64 : Nat64;
        #sint32 : Int32;
        #sint64 : Int64;
        #fixed32 : Nat32;
        #fixed64 : Nat64;
        #sfixed32 : Int32;
        #sfixed64 : Int64;
        #bool : Bool;
        #string : Text;
        #bytes : [Nat8];
        #float : Float;
        #double : Float;
        #enum : Int;
        #message : [Field];
        #repeated : [Value];
        #map : [(Value, Value)];
    };

    public type ValueType = {
        #int32;
        #int64;
        #uint32;
        #uint64;
        #sint32;
        #sint64;
        #fixed32;
        #fixed64;
        #sfixed32;
        #sfixed64;
        #bool;
        #string;
        #bytes;
        #float;
        #double;
        #enum;
        #message : [FieldType];
        #repeated : ValueType;
        #map : (ValueType, ValueType);
    };
};
