import Protobuf "../src";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Nat8 "mo:base/Nat8";
import { test } "mo:test";
import Blob "mo:new-base/Blob";
import List "mo:new-base/List";
import Iter "mo:new-base/Iter";
import Types "../src/Types";

func trapOrReturn<TValue, TErr>(result : Result.Result<TValue, TErr>, show : (TErr) -> Text) : TValue {
  switch (result) {
    case (#err(e)) Debug.trap("Error: " # show(e));
    case (#ok(a)) a;
  };
};

test(
  "Encoding",
  func() {
    type TestCase = {
      bytes : Blob;
      // schema : [Protobuf.FieldType];
      expected : [Protobuf.Field];
    };
    let testCases : [TestCase] = [
      {
        bytes = "\0A\04\74\65\73\74\12\02\FF\0F\18\02\22\02\02\04";
        expected = [
          { fieldNumber = 1; value = #string("test") },
          {
            fieldNumber = 2;
            value = #bytes([0xFF, 0x0F]);
          },
          {
            fieldNumber = 3;
            value = #uint64(2);
          },
          {
            fieldNumber = 4;
            value = #bytes([0x02, 0x04]);
          },
        ];
      },
      {
        bytes = "\08\2A\12\05\68\65\6C\6C\6F\25\78\56\34\12";
        expected = [
          { fieldNumber = 1; value = #uint64(42) },
          {
            fieldNumber = 2;
            value = #string("hello");
          },
          { fieldNumber = 4; value = #fixed32(0x12345678) },
        ];
      },
      {
        bytes = "";
        expected = [];
      },
      // Basic varint types
      {
        bytes = "\08\00";
        expected = [{ fieldNumber = 1; value = #int32(0) }];
      },
      {
        bytes = "\08\FF\FF\FF\FF\07";
        expected = [
          { fieldNumber = 1; value = #int32(2147483647) } // Max int32
        ];
      },
      {
        bytes = "\08\80\80\80\80\08";
        expected = [
          { fieldNumber = 1; value = #int32(-2147483648) } // Min int32
        ];
      },
      {
        bytes = "\08\FF\FF\FF\FF\FF\FF\FF\FF\7F";
        expected = [
          { fieldNumber = 1; value = #int64(9223372036854775807) } // Max int64
        ];
      },
      {
        bytes = "\08\80\80\80\80\80\80\80\80\80\01";
        expected = [
          { fieldNumber = 1; value = #int64(-9223372036854775808) } // Min int64
        ];
      },
      {
        bytes = "\08\FF\FF\FF\FF\0F";
        expected = [
          { fieldNumber = 1; value = #uint32(4294967295) } // Max uint32
        ];
      },
      {
        bytes = "\08\FF\FF\FF\FF\FF\FF\FF\FF\FF\01";
        expected = [
          { fieldNumber = 1; value = #uint64(18446744073709551615) } // Max uint64
        ];
      },

      // Signed integers with zigzag encoding
      {
        bytes = "\08\00";
        expected = [{ fieldNumber = 1; value = #sint32(0) }];
      },
      {
        bytes = "\08\01";
        expected = [{ fieldNumber = 1; value = #sint32(-1) }];
      },
      {
        bytes = "\08\02";
        expected = [{ fieldNumber = 1; value = #sint32(1) }];
      },
      {
        bytes = "\08\01";
        expected = [{ fieldNumber = 1; value = #sint64(-1) }];
      },
      {
        bytes = "\08\FE\FF\FF\FF\0F";
        expected = [{ fieldNumber = 1; value = #sint64(2147483647) }];
      },

      // Boolean values
      {
        bytes = "\08\01";
        expected = [{ fieldNumber = 1; value = #bool(true) }];
      },
      {
        bytes = "\08\00";
        expected = [{ fieldNumber = 1; value = #bool(false) }];
      },

      // Enum values
      {
        bytes = "\08\00";
        expected = [{ fieldNumber = 1; value = #enum(0) }];
      },
      {
        bytes = "\08\FF\01";
        expected = [{ fieldNumber = 1; value = #enum(255) }];
      },
      {
        bytes = "\08\FF\FF\FF\FF\0F";
        expected = [{ fieldNumber = 1; value = #enum(-1) }];
      },

      // Fixed32 types
      {
        bytes = "\0D\00\00\00\00";
        expected = [{ fieldNumber = 1; value = #fixed32(0) }];
      },
      {
        bytes = "\0D\FF\FF\FF\FF";
        expected = [
          { fieldNumber = 1; value = #fixed32(4294967295) } // Max uint32
        ];
      },
      {
        bytes = "\0D\00\00\00\00";
        expected = [{ fieldNumber = 1; value = #sfixed32(0) }];
      },
      {
        bytes = "\0D\FF\FF\FF\FF";
        expected = [{ fieldNumber = 1; value = #sfixed32(-1) }];
      },
      {
        bytes = "\0D\FF\FF\FF\7F";
        expected = [
          { fieldNumber = 1; value = #sfixed32(2147483647) } // Max int32
        ];
      },

      // Fixed64 types
      {
        bytes = "\09\00\00\00\00\00\00\00\00";
        expected = [{ fieldNumber = 1; value = #fixed64(0) }];
      },
      {
        bytes = "\09\FF\FF\FF\FF\FF\FF\FF\FF";
        expected = [
          { fieldNumber = 1; value = #fixed64(18446744073709551615) } // Max uint64
        ];
      },
      {
        bytes = "\09\00\00\00\00\00\00\00\80";
        expected = [
          { fieldNumber = 1; value = #sfixed64(-9223372036854775808) } // Min int64
        ];
      },

      // Float and double
      {
        bytes = "\0D\00\00\00\00";
        expected = [{ fieldNumber = 1; value = #float(0.0) }];
      },
      {
        bytes = "\0D\00\00\30\40";
        expected = [{ fieldNumber = 1; value = #float(2.75) }];
      },
      {
        bytes = "\0D\00\00\C0\BF";
        expected = [{ fieldNumber = 1; value = #float(-1.5) }];
      },
      {
        bytes = "\09\00\00\00\00\00\00\00\00";
        expected = [{ fieldNumber = 1; value = #double(0.0) }];
      },
      {
        bytes = "\09\00\00\00\00\00\00\06\40";
        expected = [{ fieldNumber = 1; value = #double(2.75) }];
      },

      // String values
      {
        bytes = "\0A\00";
        expected = [
          { fieldNumber = 1; value = #string("") } // Empty string
        ];
      },
      {
        bytes = "\0A\0B\68\65\6C\6C\6F\20\77\6F\72\6C\64";
        expected = [{ fieldNumber = 1; value = #string("hello world") }];
      },
      {
        bytes = "\0A\1A\75\6E\69\63\6F\64\65\3A\20\E4\BD\A0\E5\A5\BD\E4\B8\96\E7\95\8C\20\F0\9F\9A\80";
        expected = [{ fieldNumber = 1; value = #string("unicode: 你好世界 🚀") }];
      },
      {
        bytes = "\0A\14\73\70\65\63\69\61\6C\20\63\68\61\72\73\3A\20\0A\0D\09\5C\22";
        expected = [{
          fieldNumber = 1;
          value = #string("special chars: \n\r\t\\\"");
        }];
      },

      // Bytes values
      {
        bytes = "\0A\00";
        expected = [
          { fieldNumber = 1; value = #bytes([]) } // Empty bytes
        ];
      },
      {
        bytes = "\0A\01\00";
        expected = [{ fieldNumber = 1; value = #bytes([0x00]) }];
      },
      {
        bytes = "\0A\03\FF\FE\FD";
        expected = [{ fieldNumber = 1; value = #bytes([0xFF, 0xFE, 0xFD]) }];
      },
      {
        bytes = "\0A\05\01\02\03\04\05";
        expected = [{
          fieldNumber = 1;
          value = #bytes([0x01, 0x02, 0x03, 0x04, 0x05]);
        }];
      },

      // Nested messages
      {
        bytes = "\0A\00";
        expected = [
          { fieldNumber = 1; value = #message([]) } // Empty message
        ];
      },
      {
        bytes = "\0A\02\08\2A";
        expected = [{
          fieldNumber = 1;
          value = #message([{ fieldNumber = 1; value = #int32(42) }]);
        }];
      },
      {
        bytes = "\0A\0A\0A\06\6E\65\73\74\65\64\10\01";
        expected = [{
          fieldNumber = 1;
          value = #message([
            { fieldNumber = 1; value = #string("nested") },
            { fieldNumber = 2; value = #bool(true) },
          ]);
        }];
      },
      {
        bytes = "\0A\04\0A\02\08\7B";
        expected = [
          {
            fieldNumber = 1;
            value = #message([{
              fieldNumber = 1;
              value = #message([{ fieldNumber = 1; value = #int32(123) }]);
            }]);
          } // Deeply nested
        ];
      },

      // Repeated fields - packed

      {
        bytes = "\0A\03\01\02\03";
        expected = [{
          fieldNumber = 1;
          value = #repeated([#int32(1), #int32(2), #int32(3)]);
        }];
      },
      {
        bytes = "\0A\03\01\00\01";
        expected = [{
          fieldNumber = 1;
          value = #repeated([#bool(true), #bool(false), #bool(true)]);
        }];
      },
      {
        bytes = "\0A\03\00\01\02";
        expected = [{
          fieldNumber = 1;
          value = #repeated([#enum(0), #enum(1), #enum(2)]);
        }];
      },
      {
        bytes = "\0A\08\64\00\00\00\C8\00\00\00";
        expected = [{
          fieldNumber = 1;
          value = #repeated([#fixed32(100), #fixed32(200)]);
        }];
      },
      {
        bytes = "\0A\18\9A\99\99\99\99\99\F1\3F\9A\99\99\99\99\99\01\40\66\66\66\66\66\66\0A\40";
        expected = [{
          fieldNumber = 1;
          value = #repeated([#double(1.1), #double(2.2), #double(3.3)]);
        }];
      },

      // Repeated fields - non-packed (strings, bytes, messages)
      {
        bytes = "\0A\01\61\0A\01\62\0A\01\63";
        expected = [{
          fieldNumber = 1;
          value = #repeated([#string("a"), #string("b"), #string("c")]);
        }];
      },
      {
        bytes = "\0A\01\01\0A\01\02";
        expected = [{
          fieldNumber = 1;
          value = #repeated([#bytes([0x01]), #bytes([0x02])]);
        }];
      },
      {
        bytes = "\0A\02\08\01\0A\02\08\02";
        expected = [{
          fieldNumber = 1;
          value = #repeated([
            #message([{ fieldNumber = 1; value = #int32(1) }]),
            #message([{ fieldNumber = 1; value = #int32(2) }]),
          ]);
        }];
      },

      // Map fields
      {
        bytes = "\0A\00";
        expected = [
          { fieldNumber = 1; value = #map([]) } // Empty map
        ];
      },
      {
        bytes = "\0A\09\0A\04\6B\65\79\31\10\E4\00";
        expected = [{
          fieldNumber = 1;
          value = #map([(#string("key1"), #int32(100))]);
        }];
      },
      {
        bytes = "\0A\14\08\01\12\06\76\61\6C\75\65\31\08\02\12\06\76\61\6C\75\65\32";
        expected = [{
          fieldNumber = 1;
          value = #map([
            (#int32(1), #string("value1")),
            (#int32(2), #string("value2")),
          ]);
        }];
      },
      {
        bytes = "\0A\0C\0A\06\6E\65\73\74\65\64\12\02\08\01";
        expected = [{
          fieldNumber = 1;
          value = #map([(#string("nested"), #message([{ fieldNumber = 1; value = #bool(true) }]))]);
        }];
      },

      // Multiple fields in one message
      {
        bytes = "\08\2A\12\04\74\65\73\74\18\01";
        expected = [
          { fieldNumber = 1; value = #int32(42) },
          { fieldNumber = 2; value = #string("test") },
          { fieldNumber = 3; value = #bool(true) },
        ];
      },
      {
        bytes = "\0A\02\01\02\12\08\0A\03\6B\65\79\10\E7\07\1A\09\09\1F\85\EB\51\B8\1E\09\40";
        expected = [
          { fieldNumber = 1; value = #repeated([#int32(1), #int32(2)]) },
          { fieldNumber = 2; value = #map([(#string("key"), #int32(999))]) },
          {
            fieldNumber = 3;
            value = #message([{ fieldNumber = 1; value = #double(3.14) }]);
          },
        ];
      },

      // Edge case: High field numbers
      {
        bytes = "\F8\FF\FF\FF\0F\2A";
        expected = [
          { fieldNumber = 536870911; value = #int32(42) } // Max field number
        ];
      },
      {
        bytes = "\FA\FF\FF\3F\0A\68\69\67\68\20\66\69\65\6C\64";
        expected = [
          { fieldNumber = 16777215; value = #string("high field") } // 2^24 - 1
        ];
      },

      // Edge case: Mixed types with same field number (should combine into repeated)
      // Note: This tests the decoder's ability to handle multiple instances of same field

      // Complex combination
      {
        bytes = "\08\56\10\FF\FF\FF\FF\FF\FF\FF\FF\FF\01\18\FF\FF\FF\FF\0F\21\FF\FF\FF\FF\FF\FF\FF\7F\2A\11\63\6F\6D\70\6C\65\78\20\74\65\73\74\20\F0\9F\8E\AF\32\04\DE\AD\BE\EF\3A\0C\00\00\80\3F\00\00\00\40\00\00\40\40\42\0E\08\01\12\03\6F\6E\65\08\02\12\03\74\77\6F\4A\05\08\00\10\FF\01";
        expected = [
          { fieldNumber = 1; value = #int32(-42) },
          { fieldNumber = 2; value = #uint64(18446744073709551615) },
          { fieldNumber = 3; value = #sint32(-2147483648) },
          { fieldNumber = 4; value = #fixed64(9223372036854775807) },
          { fieldNumber = 5; value = #string("complex test 🎯") },
          { fieldNumber = 6; value = #bytes([0xDE, 0xAD, 0xBE, 0xEF]) },
          {
            fieldNumber = 7;
            value = #repeated([#float(1.0), #float(2.0), #float(3.0)]);
          },
          {
            fieldNumber = 8;
            value = #map([
              (#int32(1), #string("one")),
              (#int32(2), #string("two")),
            ]);
          },
          {
            fieldNumber = 9;
            value = #message([
              { fieldNumber = 1; value = #bool(false) },
              { fieldNumber = 2; value = #enum(255) },
            ]);
          },
        ];
      }

    ];

    for (testCase in testCases.vals()) {

      let encodeResult = Protobuf.toBytes(testCase.expected);
      let actualBytes = Blob.fromArray(trapOrReturn<[Nat8], Text>(encodeResult, func(e) { e }));

      if (actualBytes != testCase.bytes) {
        Debug.trap("Invalid encoded bytes.\nExpected: " # debug_show (testCase.bytes) # "\nActual:   " # debug_show (actualBytes) # "\nMessage: " # debug_show (testCase.expected));
      };

      let decodeResult = Protobuf.fromBytes(testCase.bytes.vals(), testCase.schema);
      let fields = trapOrReturn<[Protobuf.Field], Text>(decodeResult, func(e) { e });

      if (fields != testCase.expected) {
        Debug.trap("Invalid decoded message count.\nExpected: " # debug_show (testCase.expected) # "\nActual: " # debug_show (fields) # "\nBytes: " # debug_show (testCase.bytes));
      };
    };

  },
);

test(
  "Error Handling",
  func() {
    // Test invalid wire type
    let invalidWireType = Protobuf.fromRawBytes(Blob.fromArray([0x0B : Nat8]).vals()); // Wire type 3 (start_group) not supported
    switch (invalidWireType) {
      case (#err(errorText)) {
        // Expected some error message
        if (errorText.size() == 0) {
          Debug.trap("Expected non-empty error message");
        };
      };
      case (#ok(result)) Debug.trap("Expected error for invalid wire type, got: " # debug_show (result));
    };

    // Test unexpected end of bytes
    let truncated = Protobuf.fromRawBytes(Blob.fromArray([0x08 : Nat8]).vals()); // Tag without value
    switch (truncated) {
      case (#err(errorText)) {
        // Expected some error message
        if (errorText.size() == 0) {
          Debug.trap("Expected non-empty error message");
        };
      };
      case (#ok(result)) Debug.trap("Expected error for truncated bytes, got: " # debug_show (result));
    };

    // Test invalid field number (0)
    let invalidField = Protobuf.toBytes([{
      fieldNumber = 0;
      value = #uint64(1);
    }]);
    switch (invalidField) {
      case (#err(errorText)) {
        // Expected some error message
        if (errorText.size() == 0) {
          Debug.trap("Expected non-empty error message");
        };
      };
      case (#ok(result)) Debug.trap("Expected error for invalid field number, got: " # debug_show (result));
    };
  },
);
