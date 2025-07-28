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
import Int "mo:new-base/Int";
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
      encodeTagStatic(buffer, field.fieldNumber, wireType);
    };

    // Encode value
    switch (encodeValue(buffer, field.value, encodeTag)) {
      case (#err(e)) return #err(e);
      case (#ok) {};
    };

    #ok(buffer.size() - initialSize);
  };

  private func encodeTagStatic(
    buffer : Buffer.Buffer<Nat8>,
    fieldNumber : Nat,
    wireType : Types.WireType,
  ) {
    let wireTypeNum = switch (wireType) {
      case (#varint) 0;
      case (#fixed32) 5;
      case (#fixed64) 1;
      case (#lengthDelimited) 2;
    };
    // Encode tag (field number << 3 | wire type)
    let tag = fieldNumber * 8 + wireTypeNum;
    LEB128.toUnsignedBytesBuffer(buffer, tag);
  };

  private func encodeValue(
    buffer : Buffer.Buffer<Nat8>,
    value : Types.Value,
    encodeTag : (Types.WireType) -> (),
  ) : Result.Result<(), Text> {
    switch (value) {
      case (#int32(v)) encodeSelfContainedValue(buffer, #int32(v), encodeTag);
      case (#int64(v)) encodeSelfContainedValue(buffer, #int64(v), encodeTag);
      case (#uint32(v)) encodeSelfContainedValue(buffer, #uint32(v), encodeTag);
      case (#uint64(v)) encodeSelfContainedValue(buffer, #uint64(v), encodeTag);
      case (#sint32(v)) encodeSelfContainedValue(buffer, #sint32(v), encodeTag);
      case (#sint64(v)) encodeSelfContainedValue(buffer, #sint64(v), encodeTag);
      case (#bool(v)) encodeSelfContainedValue(buffer, #bool(v), encodeTag);
      case (#enum(v)) encodeSelfContainedValue(buffer, #enum(v), encodeTag);
      case (#fixed32(v)) encodeSelfContainedValue(buffer, #fixed32(v), encodeTag);
      case (#sfixed32(v)) encodeSelfContainedValue(buffer, #sfixed32(v), encodeTag);
      case (#float(v)) encodeSelfContainedValue(buffer, #float(v), encodeTag);
      case (#fixed64(v)) encodeSelfContainedValue(buffer, #fixed64(v), encodeTag);
      case (#sfixed64(v)) encodeSelfContainedValue(buffer, #sfixed64(v), encodeTag);
      case (#double(v)) encodeSelfContainedValue(buffer, #double(v), encodeTag);
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
        let encodeContent = func(delimitedBuffer : Buffer.Buffer<Nat8>) : Result.Result<(), Text> {
          switch (toBytesBuffer(delimitedBuffer, v)) {
            case (#err(e)) return #err(e);
            case (#ok(_)) #ok;
          };
        };
        switch (encodeLengthDelimited(buffer, encodeContent)) {
          case (#err(e)) return #err(e);
          case (#ok) ();
        };
      };
      case (#map(m)) {
        for ((key, value) in m.vals()) {
          encodeTag(#lengthDelimited);
          let encodeContent = func(delimitedBuffer : Buffer.Buffer<Nat8>) : Result.Result<(), Text> {
            let encodeTagFactory = func(fieldNumber : Nat) : (Types.WireType) -> () {
              func(wireType : Types.WireType) {
                encodeTagStatic(delimitedBuffer, fieldNumber, wireType);
              };
            };
            // Encode key field (field number 1)
            switch (encodeValue(delimitedBuffer, key, encodeTagFactory(1))) {
              case (#err(e)) return #err("Error encoding map key: " # e);
              case (#ok) ();
            };

            // Encode value field (field number 2)
            switch (encodeValue(delimitedBuffer, value, encodeTagFactory(2))) {
              case (#err(e)) return #err("Error encoding map value: " # e);
              case (#ok) ();
            };
            #ok;
          };
          switch (encodeLengthDelimited(buffer, encodeContent)) {
            case (#err(e)) return #err(e);
            case (#ok) ();
          };
        };
      };
      case (#repeated(values)) {
        if (values.size() == 0) {
          // Encode as empty packed
          encodeTag(#lengthDelimited);
          LEB128.toUnsignedBytesBuffer(buffer, 0);
          return #ok;
        };
        let ?repeatedValue = getValidRepeatedType(values) else return #err("All repeated values must be of the same type. Values: " # debug_show (values));

        if (values.size() != 1) {
          // Dont pack single values
          switch (getSelfContainedType(repeatedValue)) {
            case (?_) {
              // Encode as packed
              encodeTag(#lengthDelimited);
              let fakeEncodeTag = func(_ : Types.WireType) {}; // Packed values do not have tags
              let encodeContent = func(delimitedBuffer : Buffer.Buffer<Nat8>) : Result.Result<(), Text> {
                for (value in Iter.fromArray(values)) {
                  let ?selfContainedValue = getSelfContainedType(value) else return #err("All repeated values must be self contained types. Value: " # debug_show (value));
                  encodeSelfContainedValue(delimitedBuffer, selfContainedValue, fakeEncodeTag);
                };
                #ok;
              };
              switch (encodeLengthDelimited(buffer, encodeContent)) {
                case (#err(e)) return #err(e);
                case (#ok) ();
              };
              return #ok;
            };
            case (null) ();
          };
        };

        // Encode as unpacked as fallback
        for (value in Iter.fromArray(values)) {
          switch (encodeValue(buffer, value, encodeTag)) {
            case (#err(e)) return #err(e);
            case (#ok) ();
          };
        };
      };
    };
    #ok;
  };

  private func encodeLengthDelimited(
    buffer : Buffer.Buffer<Nat8>,
    encodeContent : (Buffer.Buffer<Nat8>) -> Result.Result<(), Text>,
  ) : Result.Result<(), Text> {
    let delimitedBuffer = Buffer.Buffer<Nat8>(64);
    switch (encodeContent(delimitedBuffer)) {
      case (#err(e)) return #err(e);
      case (#ok) ();
    };
    LEB128.toUnsignedBytesBuffer(buffer, delimitedBuffer.size());
    buffer.append(delimitedBuffer);
    #ok;
  };

  private func encodeSelfContainedValue(
    buffer : Buffer.Buffer<Nat8>,
    value : Types.SelfContainedValue,
    encodeTag : (Types.WireType) -> (),
  ) {
    switch (value) {
      case (#int32(v)) {
        encodeTag(#varint);
        let nat32Value = Nat32.toNat(Nat32.fromIntWrap(Int32.toInt(v)));
        LEB128.toUnsignedBytesBuffer(buffer, nat32Value);
      };
      case (#int64(v)) {
        encodeTag(#varint);
        let nat64Value = Nat64.toNat(Nat64.fromIntWrap(Int64.toInt(v)));
        LEB128.toUnsignedBytesBuffer(buffer, nat64Value);
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
        let nat32Value = Nat32.toNat(Nat32.fromIntWrap(Int32.toInt(v)));
        LEB128.toUnsignedBytesBuffer(buffer, nat32Value);
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
    };
  };

  private func isSameValueType(value1 : Types.Value, value2 : Types.Value) : Bool {
    switch ((value1, value2)) {
      case (#int32(_), #int32(_)) return true;
      case (#int64(_), #int64(_)) return true;
      case (#uint32(_), #uint32(_)) return true;
      case (#uint64(_), #uint64(_)) return true;
      case (#sint32(_), #sint32(_)) return true;
      case (#sint64(_), #sint64(_)) return true;
      case (#bool(_), #bool(_)) return true;
      case (#enum(_), #enum(_)) return true;
      case (#fixed32(_), #fixed32(_)) return true;
      case (#sfixed32(_), #sfixed32(_)) return true;
      case (#fixed64(_), #fixed64(_)) return true;
      case (#sfixed64(_), #sfixed64(_)) return true;
      case (#float(_), #float(_)) return true;
      case (#double(_), #double(_)) return true;
      case (#string(_), #string(_)) return true;
      case (#bytes(_), #bytes(_)) return true;
      case (#message(m1), #message(m2)) {
        if (m1.size() != m2.size()) return false;
        for ((m1Item, m2Item) in Iter.zip(m1.vals(), m2.vals())) {
          if (m1Item.fieldNumber != m2Item.fieldNumber) return false;
          if (not isSameValueType(m1Item.value, m2Item.value)) return false;
        };
        true;
      };
      case (#map(m1), #map(m2)) {
        if (m1.size() != m2.size()) return false;
        for (((m1ItemKey, m1ItemValue), (m2ItemKey, m2ItemValue)) in Iter.zip(m1.vals(), m2.vals())) {
          if (not isSameValueType(m1ItemKey, m2ItemKey)) return false;
          if (not isSameValueType(m1ItemValue, m2ItemValue)) return false;
        };
        true;
      };
      case (#repeated(v1), #repeated(v2)) {
        let ?value1 = getValidRepeatedType(v1) else return false;
        let ?value2 = getValidRepeatedType(v2) else return false;
        isSameValueType(value1, value2);
      };
      case (_, _) return false; // Different types
    };
  };

  private func getValidRepeatedType(repeated : [Types.Value]) : ?Types.Value {
    let firstValue = repeated[0];
    // Check if all values are of the same type
    for (value in Iter.drop(repeated.vals(), 1)) {
      if (not isSameValueType(firstValue, value)) {
        return null;
      };
    };
    ?firstValue;
  };

  private func getSelfContainedType(value : Types.Value) : ?Types.SelfContainedValue {
    switch (value) {
      case (#int32(int32)) ?#int32(int32);
      case (#int64(int64)) ?#int64(int64);
      case (#uint32(uint32)) ?#uint32(uint32);
      case (#uint64(uint64)) ?#uint64(uint64);
      case (#sint32(sint32)) ?#sint32(sint32);
      case (#sint64(sint64)) ?#sint64(sint64);
      case (#bool(bool)) ?#bool(bool);
      case (#enum(enumValue)) ?#enum(enumValue);
      case (#fixed32(fixed32)) ?#fixed32(fixed32);
      case (#sfixed32(sfixed32)) ?#sfixed32(sfixed32);
      case (#fixed64(fixed64)) ?#fixed64(fixed64);
      case (#sfixed64(sfixed64)) ?#sfixed64(sfixed64);
      case (#float(floatValue)) ?#float(floatValue);
      case (#double(doubleValue)) ?#double(doubleValue);
      case (_) null;
    };
  };

  private func zigzagEncode32(value : Int32) : Nat32 {
    let v = Int32.toInt(value);
    if (value >= 0) {
      Nat32.fromNat(Nat.fromInt(v) * 2);
    } else {
      Nat32.fromNat((Int.abs(v) - 1) * 2 + 1);
    };
  };

  private func zigzagEncode64(value : Int64) : Nat64 {
    let v = Int64.toInt(value);
    if (value >= 0) {
      Nat64.fromNat(Nat.fromInt(v) * 2);
    } else {
      Nat64.fromNat((Int.abs(v) - 1) * 2 + 1);
    };
  };
};
