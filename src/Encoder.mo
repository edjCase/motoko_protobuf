import Buffer "mo:base/Buffer";
import Int32 "mo:new-base/Int32";
import Int64 "mo:new-base/Int64";
import Nat8 "mo:new-base/Nat8";
import Nat32 "mo:new-base/Nat32";
import Nat64 "mo:new-base/Nat64";
import Nat "mo:new-base/Nat";
import Result "mo:new-base/Result";
import Text "mo:new-base/Text";
import Iter "mo:new-base/Iter";
import Types "./Types";
import LEB128 "mo:leb128";
import FloatX "mo:xtended-numbers/FloatX";
import NatX "mo:xtended-numbers/NatX";
import IntX "mo:xtended-numbers/IntX";

module {
    public func toBytes(message : [Types.Field]) : Result.Result<[Nat8], Text> {
        let buffer = Buffer.Buffer<Nat8>(64);
        switch (toBytesBuffer(buffer, message)) {
            case (#ok(_)) #ok(Buffer.toArray(buffer));
            case (#err(e)) #err(e);
        };
    };

    public func toBytesBuffer(
        buffer : Buffer.Buffer<Nat8>,
        message : [Types.Field],
    ) : Result.Result<Nat, Text> {
        let initialSize = buffer.size();
        for (field in Iter.fromArray(message)) {
            switch (fieldToBytesBuffer(buffer, field)) {
                case (#err(e)) return #err(e);
                case (#ok(_)) {};
            };
        };
        #ok(buffer.size() - initialSize);
    };

    private func fieldToBytesBuffer(
        buffer : Buffer.Buffer<Nat8>,
        field : Types.Field,
    ) : Result.Result<Nat, Text> {
        let initialSize = buffer.size();

        // Validate field number
        if (field.fieldNumber == 0 or field.fieldNumber > 536870911) {
            // 2^29 - 1
            return #err("Invalid field number (0 -> 2^29 - 1): " # Nat.toText(field.fieldNumber));
        };

        func encodeTag(wireType : Types.WireType) {
            let wireTypeNum = switch (wireType) {
                case (#varint) 0;
                case (#fixed32) 5;
                case (#fixed64) 1;
                case (#lengthDelimited) 2;
            };
            // Encode tag (field number << 3 | wire type)
            let tag = field.fieldNumber * 8 + wireTypeNum;
            LEB128.toUnsignedBytesBuffer(buffer, tag);
        };

        // Encode value
        switch (encodeValue(buffer, field.value, encodeTag)) {
            case (#err(e)) return #err(e);
            case (#ok) {};
        };

        #ok(buffer.size() - initialSize);
    };

    private func encodeValue(
        buffer : Buffer.Buffer<Nat8>,
        value : Types.Value,
        encodeTag : (Types.WireType) -> (),
    ) : Result.Result<(), Text> {
        switch (value) {
            case (#int32(v)) {
                encodeTag(#varint);
                LEB128.toSignedBytesBuffer(buffer, Int32.toInt(v));
            };
            case (#int64(v)) {
                encodeTag(#varint);
                LEB128.toSignedBytesBuffer(buffer, Int64.toInt(v));
            };
            case (#uint32(v)) {
                encodeTag(#varint);
                LEB128.toUnsignedBytesBuffer(buffer, Nat32.toNat(v));
            };
            case (#uint64(v)) {
                encodeTag(#varint);
                LEB128.toUnsignedBytesBuffer(buffer, Nat64.toNat(v));
            };
            case (#sint32(v)) {
                encodeTag(#varint);
                let zigzag = zigzagEncode32(v);
                LEB128.toUnsignedBytesBuffer(buffer, Nat32.toNat(zigzag));
            };
            case (#sint64(v)) {
                encodeTag(#varint);
                let zigzag = zigzagEncode64(v);
                LEB128.toUnsignedBytesBuffer(buffer, Nat64.toNat(zigzag));
            };
            case (#bool(v)) {
                encodeTag(#varint);
                LEB128.toUnsignedBytesBuffer(buffer, if (v) 1 else 0);
            };
            case (#enum(v)) {
                encodeTag(#varint);
                LEB128.toSignedBytesBuffer(buffer, v);
            };
            case (#fixed32(v)) {
                encodeTag(#fixed32);
                NatX.encodeNat32(buffer, v, #lsb);
            };
            case (#sfixed32(v)) {
                encodeTag(#fixed32);
                IntX.encodeInt32(buffer, v, #lsb);
            };
            case (#float(v)) {
                encodeTag(#fixed32);
                let floatX = FloatX.fromFloat(v, #f32);
                FloatX.encode(buffer, floatX, #lsb);
            };
            case (#fixed64(v)) {
                encodeTag(#fixed64);
                NatX.encodeNat64(buffer, v, #lsb);
            };
            case (#sfixed64(v)) {
                encodeTag(#fixed64);
                IntX.encodeInt64(buffer, v, #lsb);
            };
            case (#double(v)) {
                encodeTag(#fixed64);
                let floatX = FloatX.fromFloat(v, #f64);
                FloatX.encode(buffer, floatX, #lsb);
            };
            case (#string(v)) {
                encodeTag(#lengthDelimited);
                let utf8Bytes = Text.encodeUtf8(v);
                LEB128.toUnsignedBytesBuffer(buffer, utf8Bytes.size());
                for (byte in utf8Bytes.vals()) {
                    buffer.add(byte);
                };
            };
            case (#bytes(v)) {
                encodeTag(#lengthDelimited);
                LEB128.toUnsignedBytesBuffer(buffer, v.size());
                for (byte in Iter.fromArray(v)) {
                    buffer.add(byte);
                };
            };
            case (#message(v)) {
                encodeTag(#lengthDelimited);
                switch (toBytesBuffer(buffer, v)) {
                    case (#err(e)) return #err(e);
                    case (#ok(_)) ();
                };
            };
            case (#map(m)) {
                // TODO
                encodeTag(#lengthDelimited);
            };
            case (#repeated(values)) {
                let isAllPrimitives = Iter.all(values.vals(), isPrimitiveValue);
                if (isAllPrimitives) {
                    // Encode as packed
                    encodeTag(#lengthDelimited);
                    // TODO how to handle packed repeated fields
                } else {
                    // Encode as unpacked
                    for (value in Iter.fromArray(values)) {
                        switch (encodeValue(buffer, value, encodeTag)) {
                            case (#err(e)) return #err(e);
                            case (#ok) ();
                        };
                    };
                };
            };
        };
        #ok;
    };

    private func isPrimitiveValue(value : Types.Value) : Bool {
        switch (value) {
            case (#int32(_)) return true;
            case (#int64(_)) return true;
            case (#uint32(_)) return true;
            case (#uint64(_)) return true;
            case (#sint32(_)) return true;
            case (#sint64(_)) return true;
            case (#bool(_)) return true;
            case (#fixed32(_)) return true;
            case (#sfixed32(_)) return true;
            case (#float(_)) return true;
            case (#fixed64(_)) return true;
            case (#sfixed64(_)) return true;
            case (#double(_)) return true;
            case (#string(_)) return true;
            case (#bytes(_)) return true;
            case (_) return false;
        };
    };

    private func zigzagEncode32(value : Int32) : Nat32 {
        let v = Int32.toInt(value);
        if (value >= 0) {
            Nat32.fromNat(Nat.fromInt(v) * 2);
        } else {
            Int32.toNat32((Int32.abs(value) - 1) * 2 + 1);
        };
    };

    private func zigzagEncode64(value : Int64) : Nat64 {
        let v = Int64.toInt(value);
        if (value >= 0) {
            Nat64.fromNat(Nat.fromInt(v) * 2);
        } else {
            Int64.toNat64((Int64.abs(value) - 1) * 2 + 1);
        };
    };
};
