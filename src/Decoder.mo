import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Int32 "mo:new-base/Int32";
import Int64 "mo:new-base/Int64";
import Nat8 "mo:new-base/Nat8";
import Nat32 "mo:new-base/Nat32";
import Nat64 "mo:new-base/Nat64";
import Result "mo:new-base/Result";
import Text "mo:new-base/Text";
import Iter "mo:new-base/Iter";
import Types "./Types";
import PeekableIter "mo:xtended-iter/PeekableIter";
import LEB128 "mo:leb128";
import Nat "mo:new-base/Nat";
import List "mo:new-base/List";
import Runtime "mo:new-base/Runtime";
import Blob "mo:new-base/Blob";
import IntX "mo:xtended-numbers/IntX";
import NatX "mo:xtended-numbers/NatX";
import Map "mo:new-base/Map";

module {

    public func fromBytes(bytes : Iter.Iter<Nat8>, schema : [Types.FieldType]) : Result.Result<[Types.Field], Text> {
        let schemalessFields = switch (fromSchemalessBytes(bytes)) {
            case (#err(e)) return #err(e);
            case (#ok(fields)) fields;
        };
        type SingleValueOrRepeated = {
            #single : Value;
            #repeated : List.List<Value>;
        };
        let schemaMap = schema.vals()
        |> Iter.map<Types.FieldType, (Nat, Types.ValueType)>(
            _,
            func(fieldType : Types.FieldType) : (Nat, Types.ValueType) {
                (fieldType.fieldNumber, fieldType.valueType);
            },
        )
        |> Map.fromIter<Nat, Types.ValueType>(_, Nat.compare);
        let fieldMap = Map.empty<Nat, SingleValueOrRepeated>();
        for (field in schemalessFields.vals()) {
            let ?fieldSchema = Map.get(schemaMap, Nat.compare, field.fieldNumber) else return #err("Field number " # Nat.toText(field.fieldNumber) # " not found in schema");
            let value = switch (getValueWithType(field.wireType, field.value, fieldSchema)) {
                case (#err(e)) return #err("Error decoding field " # Nat.toText(field.fieldNumber) # ": " # e);
                case (#ok(v)) v;
            };
            switch (Map.get(fieldMap, Nat.compare, field.fieldNumber)) {
                case (null) Map.add(fieldMap, Nat.compare, field.fieldNumber, #single(value));
                case (?f) switch (f) {
                    case (#single(existingValue)) {
                        let repeatedList = List.empty<Value>();
                        List.add(repeatedList, existingValue);
                        List.add(repeatedList, value);
                        Map.add(fieldMap, Nat.compare, field.fieldNumber, #repeated(repeatedList));
                    };
                    case (#repeated(existingValues)) List.add(existingValues, value);
                };
            };
        };
        let fields = Map.entries(fieldMap)
        |> Iter.map(
            _,
            func((number, fieldStorage) : (Nat, SingleValueOrRepeated)) : Types.Field {
                let value = switch (fieldStorage) {
                    case (#single(value)) value;
                    case (#repeated(fields)) #repeated(List.toArray(fields));
                };
                {
                    fieldNumber = number;
                    value = value;
                };
            },
        )
        |> Iter.toArray(_);
        #ok(fields);
    };

    public func fromSchemalessBytes(bytes : Iter.Iter<Nat8>) : Result.Result<[Types.SchemalessField], Text> {
        let decoder = SchemalessProtobufDecoder(bytes);
        decoder.decode();
    };

    type VarintValue = {
        #int32 : Int32;
        #int64 : Int64;
        #uint32 : Nat32;
        #uint64 : Nat64;
        #sint32 : Int32;
        #sint64 : Int64;
        #bool : Bool;
        #enum : Int;
    };

    type Fixed32Value = {
        #int32 : Int32;
        #uint32 : Nat32;
        #bool : Bool;
        #enum : Int;
    };

    type Fixed64Value = {
        #int64 : Int64;
        #uint64 : Nat64;
        #bool : Bool;
        #enum : Int;
    };

    type LengthDelimitedValue = {
        #string : Text;
        #bytes : [Nat8];
        #message : [Types.Field];
        #mapEntry : (Value, Value);
        #packedRepeated : [Value];
    };

    type Value = VarintValue or Fixed32Value or Fixed64Value or LengthDelimitedValue;

    private func getValueWithType(
        wireType : Types.WireType,
        value : [Nat8],
        valueType : Types.ValueType,
    ) : Result.Result<Value, Text> {
        switch (wireType) {
            case (#varint) getVarintValue(value, valueType);
            case (#fixed32) getFixed32Value(value, valueType);
            case (#fixed64) getFixed64Value(value, valueType);
            case (#lengthDelimited) getLengthDelimitedValue(value, valueType);
        };
    };

    private func getVarintValue(
        value : [Nat8],
        valueType : Types.ValueType,
    ) : Result.Result<VarintValue, Text> {
        let trueValue : VarintValue = switch (valueType) {
            case (#int32) {
                let decoded = switch (LEB128.fromSignedBytes(value.vals())) {
                    case (#err(e)) return #err("Invalid varint: " # e);
                    case (#ok(v)) v;
                };
                if (decoded > 0x7FFFFFFF or decoded < -0x80000000) {
                    return #err("Varint exceeds Int32 range: " # Int.toText(decoded));
                };
                #int32(Int32.fromInt(decoded));
            };
            case (#int64) {
                let decoded = switch (LEB128.fromSignedBytes(value.vals())) {
                    case (#err(e)) return #err("Invalid varint: " # e);
                    case (#ok(v)) v;
                };
                if (decoded > 0x7FFFFFFFFFFFFFFF or decoded < -0x8000000000000000) {
                    return #err("Varint exceeds Int64 range: " # Int.toText(decoded));
                };
                #int64(Int64.fromInt(decoded));
            };
            case (#uint32) {
                let decoded = switch (LEB128.fromUnsignedBytes(value.vals())) {
                    case (#err(e)) return #err("Invalid varint: " # e);
                    case (#ok(v)) v;
                };
                if (decoded > 0xFFFFFFFF) {
                    return #err("Varint exceeds Uint32 range: " # Nat.toText(decoded));
                };
                #uint32(Nat32.fromNat(decoded));
            };
            case (#uint64) {
                let decoded = switch (LEB128.fromUnsignedBytes(value.vals())) {
                    case (#err(e)) return #err("Invalid varint: " # e);
                    case (#ok(v)) v;
                };
                if (decoded > 0xFFFFFFFFFFFFFFFF) {
                    return #err("Varint exceeds Uint64 range: " # Nat.toText(decoded));
                };
                #uint64(Nat64.fromNat(decoded));
            };
            case (#bool) {
                let decoded = switch (LEB128.fromUnsignedBytes(value.vals())) {
                    case (#err(e)) return #err("Invalid varint: " # e);
                    case (#ok(v)) v;
                };
                if (decoded > 1) {
                    return #err("Varint for bool must be 0 or 1: " # Nat.toText(decoded));
                };
                #bool(decoded == 1);
            };
            case (#enum) {
                let decoded = switch (LEB128.fromUnsignedBytes(value.vals())) {
                    case (#err(e)) return #err("Invalid varint: " # e);
                    case (#ok(v)) v;
                };
                #enum(decoded);
            };
            case (_) return #err("Invalid schema type for varint wire type: " # debug_show (valueType));
        };
        #ok(trueValue);
    };

    private func getFixed32Value(
        value : [Nat8],
        valueType : Types.ValueType,
    ) : Result.Result<Fixed32Value, Text> {
        if (value.size() != 4) {
            Runtime.trap("Fixed32 value must be exactly 4 bytes: " # Nat.toText(value.size()));
        };

        let trueValue : Fixed32Value = switch (valueType) {
            case (#int32) {
                let ?decoded = IntX.decodeInt32(value.vals(), #lsb) else return #err("Invalid fixed32 value for int32");
                #int32(decoded);
            };
            case (#uint32) {
                let ?decoded = NatX.decodeNat32(value.vals(), #lsb) else return #err("Invalid fixed32 value for uint32");
                #uint32(decoded);
            };
            case (#bool) {
                if (value.size() != 1) {
                    return #err("Fixed32 value for bool must be exactly 1 byte");
                };
                let decoded = value[0];
                if (decoded > 1) {
                    return #err("Fixed32 value for bool must be 0 or 1: " # Nat8.toText(decoded));
                };
                #bool(decoded == 1);
            };
            case (#enum) {
                let ?decoded = IntX.decodeInt32(value.vals(), #lsb) else return #err("Invalid fixed32 value for enum");
                #enum(Int32.toInt(decoded));
            };
            case (_) return #err("Invalid schema type for fixed32 wire type: " # debug_show (valueType));
        };
        #ok(trueValue);
    };

    private func getFixed64Value(
        value : [Nat8],
        valueType : Types.ValueType,
    ) : Result.Result<Fixed64Value, Text> {
        if (value.size() != 8) {
            Runtime.trap("Fixed64 value must be exactly 8 bytes: " # Nat.toText(value.size()));
        };

        let trueValue : Fixed64Value = switch (valueType) {
            case (#int64) {
                let ?decoded = IntX.decodeInt64(value.vals(), #lsb) else return #err("Invalid fixed64 value for int64");
                #int64(decoded);
            };
            case (#uint64) {
                let ?decoded = NatX.decodeNat64(value.vals(), #lsb) else return #err("Invalid fixed64 value for uint64");
                #uint64(decoded);
            };
            case (#bool) {
                if (value.size() != 1) {
                    return #err("Fixed64 value for bool must be exactly 1 byte");
                };
                let decoded = value[0];
                if (decoded > 1) {
                    return #err("Fixed64 value for bool must be 0 or 1: " # Nat8.toText(decoded));
                };
                #bool(decoded == 1);
            };
            case (#enum) {
                let ?decoded = IntX.decodeInt64(value.vals(), #lsb) else return #err("Invalid fixed64 value for enum");
                #enum(Int64.toInt(decoded));
            };
            case (_) return #err("Invalid schema type for fixed64 wire type: " # debug_show (valueType));
        };
        #ok(trueValue);
    };

    private func getLengthDelimitedValue(
        value : [Nat8],
        valueType : Types.ValueType,
    ) : Result.Result<LengthDelimitedValue, Text> {
        let trueValue : LengthDelimitedValue = switch (valueType) {
            case (#string) {
                let ?string = Text.decodeUtf8(Blob.fromArray(value)) else return #err("Invalid UTF-8 string in length-delimited value");
                #string(string);
            };
            case (#bytes) #bytes(value);
            case (#message(message)) return fromBytes(value.vals(), message);
            case (#repeated(repeatedType)) {
                let iter = PeekableIter.fromIter(value.vals());
                let repeatedValues = List.empty<Value>();
                getValueWithType(repeatedType.wireType, value, repeatedType.valueType);
                #packedRepeated(List.toArray(repeatedValues));
            };
            case (#map(mapType)) switch (getMapEntry(value, mapType)) {
                case (#err(e)) return #err("Error decoding map entry: " # e);
                case (#ok((key, val))) #mapEntry((key, val));
            };
            case (_) return #err("Invalid schema type for length-delimited wire type: " # debug_show (valueType));
        };
        #ok(trueValue);
    };

    private func getMapEntry(
        value : [Nat8],
        (keyType, valueType) : (Types.ValueType, Types.ValueType),
    ) : Result.Result<(Value, Value), Text> {

        let decoder = SchemalessProtobufDecoder(value.vals());
        let fields = switch (decoder.decode()) {
            case (#err(e)) return #err("Error decoding map entry: " # e);
            case (#ok(fields)) fields;
        };
        if (fields.size() != 2) {
            return #err("Map entry must have exactly 2 fields, got: " # Nat.toText(fields.size()));
        };

        let keyField = fields[0];
        let valueField = fields[1];
        // Decode key
        let key = switch (getValueWithType(keyField.wireType, keyField.value, keyType)) {
            case (#err(e)) return #err("Error decoding map key: " # e);
            case (#ok(v)) v;
        };

        // Decode value
        let val = switch (getValueWithType(valueField.wireType, valueField.value, valueType)) {
            case (#err(e)) return #err("Error decoding map value: " # e);
            case (#ok(v)) v;
        };

        #ok((key, val));
    };

    private class SchemalessProtobufDecoder(bytes : Iter.Iter<Nat8>) {
        let peekableIter = PeekableIter.fromIter(bytes);

        public func decode() : Result.Result<[Types.SchemalessField], Text> {
            let fields = Buffer.Buffer<Types.SchemalessField>(5);
            while (PeekableIter.hasNext(peekableIter)) {
                // Decode each field until we reach the end of the input
                switch (decodeField()) {
                    case (#err(e)) return #err(e);
                    case (#ok(field)) fields.add(field);
                };
            };
            #ok(Buffer.toArray(fields));
        };

        private func decodeField() : Result.Result<Types.SchemalessField, Text> {
            // Read and decode tag (field number + wire type)
            let tag = switch (LEB128.fromUnsignedBytes(peekableIter)) {
                case (#err(e)) return #err("Invalid varint: " # e);
                case (#ok(v)) v;
            };

            let wireTypeNum = Nat8.fromNat(tag % 8);
            let fieldNumber = tag / 8;

            // Validate field number
            if (fieldNumber == 0 or fieldNumber > 536870911) {
                return #err("Invalid field number (0 -> 2^29 - 1): " # Nat.toText(fieldNumber));
            };

            // Parse wire type
            let wireType : Types.WireType = switch (wireTypeNum) {
                case (0) #varint;
                case (1) #fixed64;
                case (2) #lengthDelimited;
                case (5) #fixed32;
                case (wt) return #err("Invalid wire type: " # Nat8.toText(wt));
            };

            // Decode value based on wire type
            let value = switch (decodeValue(wireType)) {
                case (#err(e)) return #err(e);
                case (#ok(v)) v;
            };

            #ok({
                fieldNumber = fieldNumber;
                wireType = wireType;
                value = value;
            });
        };

        private func decodeValue(wireType : Types.WireType) : Result.Result<[Nat8], Text> {
            let length : Nat = switch (wireType) {
                case (#varint) {
                    let leb128Bytes = List.empty<Nat8>();
                    var complete = false;
                    label f for (byte in peekableIter) {
                        List.add(leb128Bytes, byte);
                        if (byte < 128) {
                            // Last byte of varint
                            complete := true;
                            break f;
                        };
                    };
                    if (not complete) {
                        return #err("Unexpected end of bytes while reading varint");
                    };
                    return #ok(List.toArray(leb128Bytes));
                };
                case (#fixed32) 32;
                case (#fixed64) 64;
                case (#lengthDelimited) switch (LEB128.fromUnsignedBytes(peekableIter)) {
                    case (#err(e)) return #err("Invalid  varint: " # e);
                    case (#ok(len)) len;
                };
            };
            #ok(Iter.toArray(Iter.take(peekableIter, length)));
        };
    };

    private func zigzagDecode32(encoded : Nat32) : Int32 {
        if (encoded % 2 == 0) {
            Int32.fromNat32(encoded / 2);
        } else {
            -Int32.fromNat32(encoded / 2) - 1;
        };
    };

    private func zigzagDecode64(encoded : Nat64) : Int64 {
        if (encoded % 2 == 0) {
            Int64.fromNat64(encoded / 2);
        } else {
            -Int64.fromNat64(encoded / 2) - 1;
        };
    };

};
