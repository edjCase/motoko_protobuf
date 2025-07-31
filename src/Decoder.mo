import Int "mo:core/Int";
import Int32 "mo:core/Int32";
import Int64 "mo:core/Int64";
import Nat8 "mo:core/Nat8";
import Nat32 "mo:core/Nat32";
import Nat64 "mo:core/Nat64";
import Result "mo:core/Result";
import Text "mo:core/Text";
import Iter "mo:core/Iter";
import Types "./Types";
import PeekableIter "mo:xtended-iter/PeekableIter";
import LEB128 "mo:leb128";
import Nat "mo:core/Nat";
import List "mo:core/List";
import Runtime "mo:core/Runtime";
import Blob "mo:core/Blob";
import NatX "mo:xtended-numbers/NatX";
import FloatX "mo:xtended-numbers/FloatX";
import Map "mo:core/Map";
import Array "mo:core/Array";

module {

  /// Decodes protobuf binary data into typed fields using a schema.
  ///
  /// Takes a byte iterator containing protobuf binary data and a schema defining
  /// the expected field types, then parses and validates the data according to
  /// the schema to produce typed protobuf fields.
  ///
  /// # Parameters
  /// - `bytes`: Iterator over the protobuf binary data bytes
  /// - `schema`: Array of field type definitions for validation and typing
  ///
  /// # Returns
  /// - `#ok([Types.Field])`: Successfully decoded and typed fields
  /// - `#err(Text)`: Error message describing parsing or validation failure
  ///
  /// # Example
  /// ```motoko
  /// let schema = [{ fieldNumber = 1; valueType = #string }];
  /// let bytes = [0x0A, 0x05, 0x48, 0x65, 0x6C, 0x6C, 0x6F].vals(); // "Hello"
  /// switch (fromBytes(bytes, schema)) {
  ///   case (#ok(fields)) { /* Successfully decoded fields */ };
  ///   case (#err(error)) { /* Handle decoding error */ };
  /// };
  /// ```
  public func fromBytes(bytes : Iter.Iter<Nat8>, schema : [Types.FieldType]) : Result.Result<[Types.Field], Text> {
    let rawFields = switch (fromRawBytes(bytes)) {
      case (#err(e)) return #err(e);
      case (#ok(fields)) fields;
    };
    fromRawFields(rawFields, schema);
  };

  /// Decodes protobuf binary data into raw, untyped fields.
  ///
  /// Parses protobuf wire format data without applying any type schema,
  /// returning raw field data with field numbers, wire types, and raw byte values.
  /// This is useful for initial parsing or when working with unknown message types.
  ///
  /// # Parameters
  /// - `bytes`: Iterator over the protobuf binary data bytes
  ///
  /// # Returns
  /// - `#ok([Types.RawField])`: Successfully parsed raw fields
  /// - `#err(Text)`: Error message describing parsing failure
  ///
  /// # Example
  /// ```motoko
  /// let bytes = [0x08, 0x96, 0x01].vals(); // varint field
  /// switch (fromRawBytes(bytes)) {
  ///   case (#ok(rawFields)) { /* Process raw field data */ };
  ///   case (#err(error)) { /* Handle parsing error */ };
  /// };
  /// ```
  public func fromRawBytes(bytes : Iter.Iter<Nat8>) : Result.Result<[Types.RawField], Text> {
    let decoder = RawProtobufDecoder(bytes);
    decoder.decode();
  };

  /// Converts raw protobuf fields into typed fields using a schema.
  ///
  /// Takes raw field data (typically from `fromRawBytes`) and applies type
  /// information from a schema to create properly typed protobuf fields.
  /// Handles field merging for repeated fields and validates field types.
  ///
  /// # Parameters
  /// - `rawFields`: Array of raw field data with field numbers and byte values
  /// - `schema`: Array of field type definitions for validation and typing
  ///
  /// # Returns
  /// - `#ok([Types.Field])`: Successfully converted typed fields
  /// - `#err(Text)`: Error message describing conversion or validation failure
  ///
  /// # Example
  /// ```motoko
  /// let rawFields = [{ fieldNumber = 1; wireType = #varint; value = [0x08] }];
  /// let schema = [{ fieldNumber = 1; valueType = #bool }];
  /// switch (fromRawFields(rawFields, schema)) {
  ///   case (#ok(fields)) { /* Process typed fields */ };
  ///   case (#err(error)) { /* Handle conversion error */ };
  /// };
  /// ```
  public func fromRawFields(
    rawFields : [Types.RawField],
    schema : [Types.FieldType],
  ) : Result.Result<[Types.Field], Text> {
    let schemaMap = schema.vals()
    |> Iter.map<Types.FieldType, (Nat, Types.ValueType)>(
      _,
      func(fieldType : Types.FieldType) : (Nat, Types.ValueType) {
        (fieldType.fieldNumber, fieldType.valueType);
      },
    )
    |> Map.fromIter<Nat, Types.ValueType>(_, Nat.compare);
    let fieldMap = Map.empty<Nat, Types.Value>();
    for (field in rawFields.vals()) {
      let ?fieldSchema = Map.get(schemaMap, Nat.compare, field.fieldNumber) else return #err("Field number " # Nat.toText(field.fieldNumber) # " not found in schema. Raw protobuf fields: " # debug_show (rawFields));
      let value = switch (decodeRawValue(field.value, fieldSchema)) {
        case (#err(e)) return #err("Error decoding field " # Nat.toText(field.fieldNumber) # ": " # e);
        case (#ok(v)) v;
      };
      switch (Map.get(fieldMap, Nat.compare, field.fieldNumber)) {
        case (null) Map.add(fieldMap, Nat.compare, field.fieldNumber, value);
        case (?existingFieldValue) switch (existingFieldValue) {
          case (#repeated(repeatedValues)) {
            let newValues = switch (value) {
              case (#repeated(newValues)) newValues;
              case (value) [value];
            };
            // TODO optimize
            let newRepeatedValues = Array.concat(repeatedValues, newValues);
            Map.add(fieldMap, Nat.compare, field.fieldNumber, #repeated(newRepeatedValues));
          };
          case (#map(existingMapValues)) {
            // TODO optimize
            let #map(mapValues) = value else return #err("Expected map value for field " # Nat.toText(field.fieldNumber));
            let newMapValues = Array.concat(existingMapValues, mapValues);
            Map.add(fieldMap, Nat.compare, field.fieldNumber, #map(newMapValues));
          };
          case (existingFieldValue) {
            // Single value, convert to repeated
            Map.add(fieldMap, Nat.compare, field.fieldNumber, #repeated([existingFieldValue, value]));
          };
        };
      };
    };
    let fields = schema.vals()
    |> Iter.filterMap(
      _,
      func(fieldType : Types.FieldType) : ?Types.Field {
        let ?value = Map.get(fieldMap, Nat.compare, fieldType.fieldNumber) else return null;
        ?{
          fieldNumber = fieldType.fieldNumber;
          value = value;
        };
      },
    )
    |> Iter.toArray(_);
    #ok(fields);
  };

  /// Decodes a raw value based on its expected type.
  ///
  /// Internal function that converts raw byte data into a properly typed value
  /// according to the specified value type. Handles all protobuf data types
  /// including primitives, strings, bytes, messages, repeated fields, and maps.
  ///
  /// # Parameters
  /// - `value`: Raw byte array containing the field value
  /// - `valueType`: Expected type for proper decoding and validation
  ///
  /// # Returns
  /// - `#ok(Types.Value)`: Successfully decoded typed value
  /// - `#err(Text)`: Error message describing decoding failure
  private func decodeRawValue(
    value : [Nat8],
    valueType : Types.ValueType,
  ) : Result.Result<Types.Value, Text> {
    switch (valueType) {
      case (#int32) getVarintValue(value.vals(), #int32);
      case (#int64) getVarintValue(value.vals(), #int64);
      case (#uint32) getVarintValue(value.vals(), #uint32);
      case (#uint64) getVarintValue(value.vals(), #uint64);
      case (#sint32) getVarintValue(value.vals(), #sint32);
      case (#sint64) getVarintValue(value.vals(), #sint64);
      case (#fixed32) getFixed32Value(value.vals(), #fixed32);
      case (#sfixed32) getFixed32Value(value.vals(), #sfixed32);
      case (#fixed64) getFixed64Value(value.vals(), #fixed64);
      case (#sfixed64) getFixed64Value(value.vals(), #sfixed64);
      case (#float) getFixed32Value(value.vals(), #float);
      case (#double) getFixed64Value(value.vals(), #double);
      case (#bool) getVarintValue(value.vals(), #bool);
      case (#enum) getVarintValue(value.vals(), #enum);
      case (#string) getLengthDelimitedValue(value, #string);
      case (#bytes) getLengthDelimitedValue(value, #bytes);
      case (#message(message)) getLengthDelimitedValue(value, #message(message));
      case (#repeated(repeatedType)) {
        // Check if this is packed based on wire format and value type
        let isPacked = switch (repeatedType) {
          case (#int32 or #int64 or #uint32 or #uint64 or #sint32 or #sint64 or #bool or #enum or #fixed32 or #sfixed32 or #float or #fixed64 or #sfixed64 or #double) {
            // Primitive numeric types can be packed
            // We assume it's packed if we're getting it as length-delimited data
            true;
          };
          case (_) false; // strings/bytes/messages are never packed
        };

        if (isPacked) {
          getLengthDelimitedValue(value, #repeated(repeatedType));
        } else {
          // Just a single repeated value
          // Will get combined into repeated group later
          decodeRawValue(value, repeatedType);
        };
      };
      case (#map(mapType)) getLengthDelimitedValue(value, #map(mapType));
    };
  };

  private func getVarintValue(
    value : Iter.Iter<Nat8>,
    valueType : Types.VarintValueType,
  ) : Result.Result<Types.VarintValue, Text> {
    let trueValue : Types.VarintValue = switch (valueType) {
      case (#int32) {
        let decoded = switch (LEB128.fromUnsignedBytes(value)) {
          case (#err(e)) return #err("Invalid varint: " # e);
          case (#ok(v)) v;
        };
        if (decoded > 0xFFFFFFFF) {
          return #err("Varint exceeds Int32 range: " # Int.toText(decoded));
        };
        #int32(Int32.fromNat32(Nat32.fromNat(decoded)));
      };
      case (#int64) {
        let decoded = switch (LEB128.fromUnsignedBytes(value)) {
          case (#err(e)) return #err("Invalid varint: " # e);
          case (#ok(v)) v;
        };
        if (decoded > 0xFFFFFFFFFFFFFFFF) {
          return #err("Varint exceeds Int64 range: " # Int.toText(decoded));
        };
        #int64(Int64.fromNat64(Nat64.fromNat(decoded)));
      };
      case (#uint32) {
        let decoded = switch (LEB128.fromUnsignedBytes(value)) {
          case (#err(e)) return #err("Invalid varint: " # e);
          case (#ok(v)) v;
        };
        if (decoded > 0xFFFFFFFF) {
          return #err("Varint exceeds Uint32 range: " # Nat.toText(decoded));
        };
        #uint32(Nat32.fromNat(decoded));
      };
      case (#uint64) {
        let decoded = switch (LEB128.fromUnsignedBytes(value)) {
          case (#err(e)) return #err("Invalid varint: " # e);
          case (#ok(v)) v;
        };
        if (decoded > 0xFFFFFFFFFFFFFFFF) {
          return #err("Varint exceeds Uint64 range: " # Nat.toText(decoded));
        };
        #uint64(Nat64.fromNat(decoded));
      };
      case (#sint32) {
        let decoded = switch (LEB128.fromUnsignedBytes(value)) {
          case (#err(e)) return #err("Invalid varint: " # e);
          case (#ok(v)) v;
        };
        let zigzagDecoded = zigzagDecode(decoded);
        if (zigzagDecoded > 0x7FFFFFFF or zigzagDecoded < -0x80000000) {
          return #err("Varint exceeds SInt32 range: " # Int.toText(zigzagDecoded));
        };
        #sint32(Int32.fromInt(zigzagDecoded));
      };
      case (#sint64) {
        let decoded = switch (LEB128.fromUnsignedBytes(value)) {
          case (#err(e)) return #err("Invalid varint: " # e);
          case (#ok(v)) v;
        };
        let zigzagDecoded = zigzagDecode(decoded);
        if (zigzagDecoded > 0x7FFFFFFFFFFFFFFF or zigzagDecoded < -0x8000000000000000) {
          return #err("Varint exceeds SInt64 range: " # Int.toText(zigzagDecoded));
        };
        #sint64(Int64.fromInt(zigzagDecoded));
      };
      case (#bool) {
        let decoded = switch (LEB128.fromUnsignedBytes(value)) {
          case (#err(e)) return #err("Invalid varint: " # e);
          case (#ok(v)) v;
        };
        if (decoded > 1) {
          return #err("Varint for bool must be 0 or 1: " # Nat.toText(decoded));
        };
        #bool(decoded == 1);
      };
      case (#enum) {
        let decoded = switch (LEB128.fromUnsignedBytes(value)) {
          case (#err(e)) return #err("Invalid varint: " # e);
          case (#ok(v)) v;
        };
        if (decoded > 0xFFFFFFFFFFFFFFFF) {
          return #err("Varint exceeds enum (nat32) range: " # Nat.toText(decoded));
        };
        #enum(Int32.fromNat32(Nat32.fromNat(decoded)));
      };
    };
    #ok(trueValue);
  };

  private func getFixed32Value(
    value : Iter.Iter<Nat8>,
    valueType : Types.Fixed32ValueType,
  ) : Result.Result<Types.Fixed32Value, Text> {

    let trueValue : Types.Fixed32Value = switch (valueType) {
      case (#fixed32) {
        let ?decoded = NatX.decodeNat32(value, #lsb) else return #err("Invalid fixed32 value");
        #fixed32(decoded);
      };
      case (#sfixed32) {
        let ?decoded = NatX.decodeNat32(value, #lsb) else return #err("Invalid sfixed32 value");
        let intValue = Int32.fromIntWrap(Nat32.toNat(decoded));
        #sfixed32(intValue);
      };
      case (#float) {
        let ?decoded = FloatX.decode(value, #f32, #lsb) else return #err("Invalid float value");
        #float(FloatX.toFloat(decoded));
      };
    };
    #ok(trueValue);
  };

  private func getFixed64Value(
    value : Iter.Iter<Nat8>,
    valueType : Types.Fixed64ValueType,
  ) : Result.Result<Types.Fixed64Value, Text> {

    let trueValue : Types.Fixed64Value = switch (valueType) {
      case (#fixed64) {
        let ?decoded = NatX.decodeNat64(value, #lsb) else return #err("Invalid fixed64 value");
        #fixed64(decoded);
      };
      case (#sfixed64) {
        let ?decoded = NatX.decodeNat64(value, #lsb) else return #err("Invalid sfixed64 value");
        let intValue = Int64.fromIntWrap(Nat64.toNat(decoded));
        #sfixed64(intValue);
      };
      case (#double) {
        let ?decoded = FloatX.decode(value, #f64, #lsb) else return #err("Invalid double value");
        #double(FloatX.toFloat(decoded));
      };
    };
    #ok(trueValue);
  };

  private func getLengthDelimitedValue(
    value : [Nat8],
    valueType : Types.NotSelfContainedValueType,
  ) : Result.Result<Types.NotSelfContainedValue, Text> {
    let trueValue : Types.NotSelfContainedValue = switch (valueType) {
      case (#string) {
        let ?string = Text.decodeUtf8(Blob.fromArray(value)) else return #err("Invalid UTF-8 string in length-delimited value");
        #string(string);
      };
      case (#bytes) #bytes(value);
      case (#message(message)) switch (fromBytes(value.vals(), message)) {
        case (#err(e)) return #err("Error decoding message: " # e);
        case (#ok(fields)) #message(fields);
      };
      case (#repeated(repeatedType)) {
        let iter = PeekableIter.fromIter(value.vals());
        let repeatedValues = List.empty<Types.SelfContainedValue>();
        while (PeekableIter.hasNext(iter)) {
          let decodedValueResult = switch (repeatedType) {
            case (#int32) getVarintValue(iter, #int32);
            case (#int64) getVarintValue(iter, #int64);
            case (#uint32) getVarintValue(iter, #uint32);
            case (#uint64) getVarintValue(iter, #uint64);
            case (#sint32) getVarintValue(iter, #sint32);
            case (#sint64) getVarintValue(iter, #sint64);
            case (#fixed32) getFixed32Value(iter, #fixed32);
            case (#sfixed32) getFixed32Value(iter, #sfixed32);
            case (#fixed64) getFixed64Value(iter, #fixed64);
            case (#sfixed64) getFixed64Value(iter, #sfixed64);
            case (#float) getFixed32Value(iter, #float);
            case (#double) getFixed64Value(iter, #double);
            case (#bool) getVarintValue(iter, #bool);
            case (#enum) getVarintValue(iter, #enum);
            case (_) Runtime.trap("Unsupported repeated type in packed field: " # debug_show (repeatedType));
          };
          let decodedValue = switch (decodedValueResult) {
            case (#err(e)) return #err("Error decoding packed repeated value: " # e);
            case (#ok(v)) v;
          };
          List.add(repeatedValues, decodedValue);
        };
        #repeated(List.toArray(repeatedValues));
      };
      case (#map(mapType)) {
        if (value.size() == 0) {
          #map([]); // Empty map
        } else {
          switch (getMapEntry(value, mapType)) {
            case (#err(e)) return #err("Error decoding map entry: " # e);
            case (#ok((key, val))) #map([(key, val)]);
          };
        };
      };
    };
    #ok(trueValue);
  };

  private func getMapEntry(
    value : [Nat8],
    (keyType, valueType) : (Types.ValueType, Types.ValueType),
  ) : Result.Result<(Types.Value, Types.Value), Text> {

    let decoder = RawProtobufDecoder(value.vals());
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
    let key = switch (decodeRawValue(keyField.value, keyType)) {
      case (#err(e)) return #err("Error decoding map key: " # e);
      case (#ok(v)) v;
    };

    // Decode value
    let val = switch (decodeRawValue(valueField.value, valueType)) {
      case (#err(e)) return #err("Error decoding map value: " # e);
      case (#ok(v)) v;
    };

    #ok((key, val));
  };

  private class RawProtobufDecoder(bytes : Iter.Iter<Nat8>) {
    let peekableIter = PeekableIter.fromIter(bytes);

    public func decode() : Result.Result<[Types.RawField], Text> {
      let fields = List.empty<Types.RawField>();
      while (PeekableIter.hasNext(peekableIter)) {
        // Decode each field until we reach the end of the input
        switch (decodeField()) {
          case (#err(e)) return #err(e);
          case (#ok(field)) List.add(fields, field);
        };
      };
      #ok(List.toArray(fields));
    };

    private func decodeField() : Result.Result<Types.RawField, Text> {
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
        case (#fixed32) 4;
        case (#fixed64) 8;
        case (#lengthDelimited) switch (LEB128.fromUnsignedBytes(peekableIter)) {
          case (#err(e)) return #err("Invalid  varint: " # e);
          case (#ok(len)) len;
        };
      };
      let valueBytes = Iter.toArray(Iter.take(peekableIter, length));
      if (valueBytes.size() != length) {
        return #err("Unexpected end of bytes while reading length-delimited value");
      };
      #ok(valueBytes);
    };
  };

  private func zigzagDecode(encoded : Nat) : Int {
    if (encoded % 2 == 0) {
      encoded / 2;
    } else {
      -(encoded / 2) - 1;
    };
  };

};
