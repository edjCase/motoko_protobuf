import Types "Types";
import Encoder "Encoder";
import Decoder "Decoder";

module {

    /// Represents a single field in a Protobuf message.
    /// Contains field number, wire type, and the actual value.
    public type Field = Types.Field;

    public type FieldType = Types.FieldType;

    /// Represents a raw field in a Protobuf message.
    /// Contains field number, wire type, and raw byte value.
    public type RawField = Types.RawField;

    /// Represents the wire type of a Protobuf field.
    /// Determines how the value is encoded on the wire.
    public type WireType = Types.WireType;

    /// Represents the value of a Protobuf field.
    /// The value type corresponds to the wire type.
    public type Value = Types.Value;

    public type ValueType = Types.ValueType;

    public let toBytes = Encoder.toBytes;

    public let toBytesBuffer = Encoder.toBytesBuffer;

    public let fromBytes = Decoder.fromBytes;

    public let fromRawBytes = Decoder.fromRawBytes;
};
