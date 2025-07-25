module {
    public type WireType = {
        #varint;
        #fixed64;
        #lengthDelimited;
        #fixed32;
    };

    public type Field = {
        fieldNumber : Nat;
        value : Value;
    };

    public type RawField = {
        fieldNumber : Nat;
        wireType : WireType;
        value : [Nat8];
    };

    public type FieldType = {
        fieldNumber : Nat;

        valueType : ValueType;
    };

    public type VarintValue = {
        #int32 : Int32;
        #int64 : Int64;
        #uint32 : Nat32;
        #uint64 : Nat64;
        #sint32 : Int32;
        #sint64 : Int64;
        #bool : Bool;
        #enum : Int32;
    };

    public type Fixed32Value = {
        #fixed32 : Nat32;
        #sfixed32 : Int32;
        #float : Float;
    };

    public type Fixed64Value = {
        #fixed64 : Nat64;
        #sfixed64 : Int64;
        #double : Float;
    };

    public type SelfContainedValue = VarintValue or Fixed32Value or Fixed64Value;

    public type NotSelfContainedValue = {
        #string : Text;
        #bytes : [Nat8];
        #message : [Field];
        #repeated : [Value];
        #map : [(Value, Value)];
    };

    public type Value = SelfContainedValue or NotSelfContainedValue;

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

    public type Fixed32ValueType = {
        #fixed32;
        #sfixed32;
        #float;
    };

    public type Fixed64ValueType = {
        #fixed64;
        #sfixed64;
        #double;
    };

    public type SelfContainedValueType = VarintValueType or Fixed32ValueType or Fixed64ValueType;

    public type NotSelfContainedValueType = {
        #string;
        #bytes;
        #message : [FieldType];
        #repeated : ValueType;
        #map : (ValueType, ValueType);
    };

    public type ValueType = SelfContainedValueType or NotSelfContainedValueType;

};
