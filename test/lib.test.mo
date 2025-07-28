import Protobuf "../src";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Nat8 "mo:base/Nat8";
import { test } "mo:test";
import Blob "mo:new-base/Blob";
import List "mo:new-base/List";
import Text "mo:new-base/Text";

test(
  "Encoding",
  func() {
    type TestCase = {
      bytes : Blob;
      schema : [Protobuf.FieldType];
      expected : [Protobuf.Field];
      outputBytes : ?Blob;
    };
    let testCases : [TestCase] = [
      {
        bytes = "\0A\04\74\65\73\74\12\02\FF\0F\18\02\22\02\02\04";
        schema = [
          { fieldNumber = 1; valueType = #string },
          { fieldNumber = 2; valueType = #bytes },
          { fieldNumber = 3; valueType = #uint64 },
          { fieldNumber = 4; valueType = #bytes },
        ];
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
        outputBytes = null;
      },
      {
        bytes = "\08\2A\12\05\68\65\6C\6C\6F\25\78\56\34\12";
        schema = [
          { fieldNumber = 1; valueType = #uint64 },
          { fieldNumber = 2; valueType = #string },
          { fieldNumber = 4; valueType = #fixed32 },
        ];
        expected = [
          { fieldNumber = 1; value = #uint64(42) },
          {
            fieldNumber = 2;
            value = #string("hello");
          },
          { fieldNumber = 4; value = #fixed32(0x12345678) },
        ];
        outputBytes = null;
      },
      {
        bytes = "";
        schema = [];
        expected = [];
        outputBytes = null;
      },
      // Basic varint types
      {
        bytes = "\08\00";
        schema = [{ fieldNumber = 1; valueType = #int32 }];
        expected = [{ fieldNumber = 1; value = #int32(0) }];
        outputBytes = null;
      },
      {
        bytes = "\08\FF\FF\FF\FF\07";
        schema = [{ fieldNumber = 1; valueType = #int32 }];
        expected = [
          { fieldNumber = 1; value = #int32(2147483647) } // Max int32
        ];
        outputBytes = null;
      },
      {
        bytes = "\08\80\80\80\80\08";
        schema = [{ fieldNumber = 1; valueType = #int32 }];
        expected = [
          { fieldNumber = 1; value = #int32(-2147483648) } // Min int32
        ];
        outputBytes = null;
      },
      {
        bytes = "\08\FF\FF\FF\FF\FF\FF\FF\FF\7F";
        schema = [{ fieldNumber = 1; valueType = #int64 }];
        expected = [
          { fieldNumber = 1; value = #int64(9223372036854775807) } // Max int64
        ];
        outputBytes = null;
      },
      {
        bytes = "\08\80\80\80\80\80\80\80\80\80\01";
        schema = [{ fieldNumber = 1; valueType = #int64 }];
        expected = [
          { fieldNumber = 1; value = #int64(-9223372036854775808) } // Min int64
        ];
        outputBytes = null;
      },
      {
        bytes = "\08\FF\FF\FF\FF\0F";
        schema = [{ fieldNumber = 1; valueType = #uint32 }];
        expected = [
          { fieldNumber = 1; value = #uint32(4294967295) } // Max uint32
        ];
        outputBytes = null;
      },
      {
        bytes = "\08\FF\FF\FF\FF\FF\FF\FF\FF\FF\01";
        schema = [{ fieldNumber = 1; valueType = #uint64 }];
        expected = [
          { fieldNumber = 1; value = #uint64(18446744073709551615) } // Max uint64
        ];
        outputBytes = null;
      },

      // Signed integers with zigzag encoding
      {
        bytes = "\08\00";
        schema = [{ fieldNumber = 1; valueType = #sint32 }];
        expected = [{ fieldNumber = 1; value = #sint32(0) }];
        outputBytes = null;
      },
      {
        bytes = "\08\01";
        schema = [{ fieldNumber = 1; valueType = #sint32 }];
        expected = [{ fieldNumber = 1; value = #sint32(-1) }];
        outputBytes = null;
      },
      {
        bytes = "\08\02";
        schema = [{ fieldNumber = 1; valueType = #sint32 }];
        expected = [{ fieldNumber = 1; value = #sint32(1) }];
        outputBytes = null;
      },
      {
        bytes = "\08\01";
        schema = [{ fieldNumber = 1; valueType = #sint64 }];
        expected = [{ fieldNumber = 1; value = #sint64(-1) }];
        outputBytes = null;
      },
      {
        bytes = "\08\FE\FF\FF\FF\0F";
        schema = [{ fieldNumber = 1; valueType = #sint64 }];
        expected = [{ fieldNumber = 1; value = #sint64(2147483647) }];
        outputBytes = null;
      },

      // Boolean values
      {
        bytes = "\08\01";
        schema = [{ fieldNumber = 1; valueType = #bool }];
        expected = [{ fieldNumber = 1; value = #bool(true) }];
        outputBytes = null;
      },
      {
        bytes = "\08\00";
        schema = [{ fieldNumber = 1; valueType = #bool }];
        expected = [{ fieldNumber = 1; value = #bool(false) }];
        outputBytes = null;
      },

      // Enum values
      {
        bytes = "\08\00";
        schema = [{ fieldNumber = 1; valueType = #enum }];
        expected = [{ fieldNumber = 1; value = #enum(0) }];
        outputBytes = null;
      },
      {
        bytes = "\08\FF\01";
        schema = [{ fieldNumber = 1; valueType = #enum }];
        expected = [{ fieldNumber = 1; value = #enum(255) }];
        outputBytes = null;
      },
      {
        bytes = "\08\FF\FF\FF\FF\0F";
        schema = [{ fieldNumber = 1; valueType = #enum }];
        expected = [{ fieldNumber = 1; value = #enum(-1) }];
        outputBytes = null;
      },

      // Fixed32 types
      {
        bytes = "\0D\00\00\00\00";
        schema = [{ fieldNumber = 1; valueType = #fixed32 }];
        expected = [{ fieldNumber = 1; value = #fixed32(0) }];
        outputBytes = null;
      },
      {
        bytes = "\0D\FF\FF\FF\FF";
        schema = [{ fieldNumber = 1; valueType = #fixed32 }];
        expected = [
          { fieldNumber = 1; value = #fixed32(4294967295) } // Max uint32
        ];
        outputBytes = null;
      },
      {
        bytes = "\0D\00\00\00\00";
        schema = [{ fieldNumber = 1; valueType = #sfixed32 }];
        expected = [{ fieldNumber = 1; value = #sfixed32(0) }];
        outputBytes = null;
      },
      {
        bytes = "\0D\FF\FF\FF\FF";
        schema = [{ fieldNumber = 1; valueType = #sfixed32 }];
        expected = [{ fieldNumber = 1; value = #sfixed32(-1) }];
        outputBytes = null;
      },
      {
        bytes = "\0D\FF\FF\FF\7F";
        schema = [{ fieldNumber = 1; valueType = #sfixed32 }];
        expected = [
          { fieldNumber = 1; value = #sfixed32(2147483647) } // Max int32
        ];
        outputBytes = null;
      },

      // Fixed64 types
      {
        bytes = "\09\00\00\00\00\00\00\00\00";
        schema = [{ fieldNumber = 1; valueType = #fixed64 }];
        expected = [{ fieldNumber = 1; value = #fixed64(0) }];
        outputBytes = null;
      },
      {
        bytes = "\09\FF\FF\FF\FF\FF\FF\FF\FF";
        schema = [{ fieldNumber = 1; valueType = #fixed64 }];
        expected = [
          { fieldNumber = 1; value = #fixed64(18446744073709551615) } // Max uint64
        ];
        outputBytes = null;
      },
      {
        bytes = "\09\00\00\00\00\00\00\00\80";
        schema = [{ fieldNumber = 1; valueType = #sfixed64 }];
        expected = [
          { fieldNumber = 1; value = #sfixed64(-9223372036854775808) } // Min int64
        ];
        outputBytes = null;
      },

      // Float and double
      {
        bytes = "\0D\00\00\00\00";
        schema = [{ fieldNumber = 1; valueType = #float }];
        expected = [{ fieldNumber = 1; value = #float(0.0) }];
        outputBytes = null;
      },
      {
        bytes = "\0D\00\00\30\40";
        schema = [{ fieldNumber = 1; valueType = #float }];
        expected = [{ fieldNumber = 1; value = #float(2.75) }];
        outputBytes = null;
      },
      {
        bytes = "\0D\00\00\C0\BF";
        schema = [{ fieldNumber = 1; valueType = #float }];
        expected = [{ fieldNumber = 1; value = #float(-1.5) }];
        outputBytes = null;
      },
      {
        bytes = "\09\00\00\00\00\00\00\00\00";
        schema = [{ fieldNumber = 1; valueType = #double }];
        expected = [{ fieldNumber = 1; value = #double(0.0) }];
        outputBytes = null;
      },
      {
        bytes = "\09\00\00\00\00\00\00\06\40";
        schema = [{ fieldNumber = 1; valueType = #double }];
        expected = [{ fieldNumber = 1; value = #double(2.75) }];
        outputBytes = null;
      },

      // String values
      {
        bytes = "\0A\00";
        schema = [{ fieldNumber = 1; valueType = #string }];
        expected = [
          { fieldNumber = 1; value = #string("") } // Empty string
        ];
        outputBytes = null;
      },
      {
        bytes = "\0A\0B\68\65\6C\6C\6F\20\77\6F\72\6C\64";
        schema = [{ fieldNumber = 1; valueType = #string }];
        expected = [{ fieldNumber = 1; value = #string("hello world") }];
        outputBytes = null;
      },
      {
        bytes = "\0A\1A\75\6E\69\63\6F\64\65\3A\20\E4\BD\A0\E5\A5\BD\E4\B8\96\E7\95\8C\20\F0\9F\9A\80";
        schema = [{ fieldNumber = 1; valueType = #string }];
        expected = [{ fieldNumber = 1; value = #string("unicode: 你好世界 🚀") }];
        outputBytes = null;
      },
      {
        bytes = "\0A\14\73\70\65\63\69\61\6C\20\63\68\61\72\73\3A\20\0A\0D\09\5C\22";
        schema = [{ fieldNumber = 1; valueType = #string }];
        expected = [{
          fieldNumber = 1;
          value = #string("special chars: \n\r\t\\\"");
        }];
        outputBytes = null;
      },

      // Bytes values
      {
        bytes = "\0A\00";
        schema = [{ fieldNumber = 1; valueType = #bytes }];
        expected = [
          { fieldNumber = 1; value = #bytes([]) } // Empty bytes
        ];
        outputBytes = null;
      },
      {
        bytes = "\0A\01\00";
        schema = [{ fieldNumber = 1; valueType = #bytes }];
        expected = [{ fieldNumber = 1; value = #bytes([0x00]) }];
        outputBytes = null;
      },
      {
        bytes = "\0A\03\FF\FE\FD";
        schema = [{ fieldNumber = 1; valueType = #bytes }];
        expected = [{ fieldNumber = 1; value = #bytes([0xFF, 0xFE, 0xFD]) }];
        outputBytes = null;
      },
      {
        bytes = "\0A\05\01\02\03\04\05";
        schema = [{ fieldNumber = 1; valueType = #bytes }];
        expected = [{
          fieldNumber = 1;
          value = #bytes([0x01, 0x02, 0x03, 0x04, 0x05]);
        }];
        outputBytes = null;
      },

      // Nested messages
      {
        bytes = "\0A\00";
        schema = [{ fieldNumber = 1; valueType = #message([]) }];
        expected = [
          { fieldNumber = 1; value = #message([]) } // Empty message
        ];
        outputBytes = null;
      },
      {
        bytes = "\0A\02\08\2A";
        schema = [{
          fieldNumber = 1;
          valueType = #message([{ fieldNumber = 1; valueType = #int32 }]);
        }];
        expected = [{
          fieldNumber = 1;
          value = #message([{ fieldNumber = 1; value = #int32(42) }]);
        }];
        outputBytes = null;
      },
      {
        bytes = "\0A\0A\0A\06\6E\65\73\74\65\64\10\01";
        schema = [{
          fieldNumber = 1;
          valueType = #message([
            { fieldNumber = 1; valueType = #string },
            { fieldNumber = 2; valueType = #bool },
          ]);
        }];
        expected = [{
          fieldNumber = 1;
          value = #message([
            { fieldNumber = 1; value = #string("nested") },
            { fieldNumber = 2; value = #bool(true) },
          ]);
        }];
        outputBytes = null;
      },
      {
        bytes = "\0A\04\0A\02\08\7B";
        schema = [{
          fieldNumber = 1;
          valueType = #message([{
            fieldNumber = 1;
            valueType = #message([{ fieldNumber = 1; valueType = #int32 }]);
          }]);
        }];
        expected = [
          {
            fieldNumber = 1;
            value = #message([{
              fieldNumber = 1;
              value = #message([{ fieldNumber = 1; value = #int32(123) }]);
            }]);
          } // Deeply nested
        ];
        outputBytes = null;
      },

      // Repeated fields - packed

      {
        bytes = "\0A\03\01\02\03";
        schema = [{ fieldNumber = 1; valueType = #repeated(#int32) }];
        expected = [{
          fieldNumber = 1;
          value = #repeated([#int32(1), #int32(2), #int32(3)]);
        }];
        outputBytes = null;
      },
      {
        bytes = "\0A\03\01\00\01";
        schema = [{ fieldNumber = 1; valueType = #repeated(#bool) }];
        expected = [{
          fieldNumber = 1;
          value = #repeated([#bool(true), #bool(false), #bool(true)]);
        }];
        outputBytes = null;
      },
      {
        bytes = "\0A\03\00\01\02";
        schema = [{ fieldNumber = 1; valueType = #repeated(#enum) }];
        expected = [{
          fieldNumber = 1;
          value = #repeated([#enum(0), #enum(1), #enum(2)]);
        }];
        outputBytes = null;
      },
      {
        bytes = "\0A\08\64\00\00\00\C8\00\00\00";
        schema = [{ fieldNumber = 1; valueType = #repeated(#fixed32) }];
        expected = [{
          fieldNumber = 1;
          value = #repeated([#fixed32(100), #fixed32(200)]);
        }];
        outputBytes = null;
      },
      {
        bytes = "\0A\18\9A\99\99\99\99\99\F1\3F\9A\99\99\99\99\99\01\40\66\66\66\66\66\66\0A\40";
        schema = [{ fieldNumber = 1; valueType = #repeated(#double) }];
        expected = [{
          fieldNumber = 1;
          value = #repeated([#double(1.1), #double(2.2), #double(3.3)]);
        }];
        outputBytes = null;
      },

      // Repeated fields - non-packed (strings, bytes, messages)
      {
        bytes = "\0A\01\61\0A\01\62\0A\01\63";
        schema = [{ fieldNumber = 1; valueType = #repeated(#string) }];
        expected = [{
          fieldNumber = 1;
          value = #repeated([#string("a"), #string("b"), #string("c")]);
        }];
        outputBytes = null;
      },
      {
        bytes = "\0A\01\01\0A\01\02";
        schema = [{ fieldNumber = 1; valueType = #repeated(#bytes) }];
        expected = [{
          fieldNumber = 1;
          value = #repeated([#bytes([0x01]), #bytes([0x02])]);
        }];
        outputBytes = null;
      },
      {
        bytes = "\0A\02\08\01\0A\02\08\02";
        schema = [{
          fieldNumber = 1;
          valueType = #repeated(#message([{ fieldNumber = 1; valueType = #int32 }]));
        }];
        expected = [{
          fieldNumber = 1;
          value = #repeated([
            #message([{ fieldNumber = 1; value = #int32(1) }]),
            #message([{ fieldNumber = 1; value = #int32(2) }]),
          ]);
        }];
        outputBytes = null;
      },

      // Map fields
      {
        bytes = "\0A\08\0A\04\6B\65\79\31\10\64";
        schema = [{ fieldNumber = 1; valueType = #map((#string, #int32)) }];
        expected = [{
          fieldNumber = 1;
          value = #map([(#string("key1"), #int32(100))]);
        }];
        outputBytes = null;
      },
      {
        bytes = "\0A\0A\08\01\12\06\76\61\6C\75\65\31\0A\0A\08\02\12\06\76\61\6C\75\65\32";
        schema = [{ fieldNumber = 1; valueType = #map((#int32, #string)) }];
        expected = [{
          fieldNumber = 1;
          value = #map([
            (#int32(1), #string("value1")),
            (#int32(2), #string("value2")),
          ]);
        }];
        outputBytes = null;
      },
      {
        bytes = "\0A\0C\0A\06\6E\65\73\74\65\64\12\02\08\01";
        schema = [{
          fieldNumber = 1;
          valueType = #map((#string, #message([{ fieldNumber = 1; valueType = #bool }])));
        }];
        expected = [{
          fieldNumber = 1;
          value = #map([(#string("nested"), #message([{ fieldNumber = 1; value = #bool(true) }]))]);
        }];
        outputBytes = null;
      },

      // Multiple fields in one message
      {
        bytes = "\08\2A\12\04\74\65\73\74\18\01";
        schema = [
          { fieldNumber = 1; valueType = #int32 },
          { fieldNumber = 2; valueType = #string },
          { fieldNumber = 3; valueType = #bool },
        ];
        expected = [
          { fieldNumber = 1; value = #int32(42) },
          { fieldNumber = 2; value = #string("test") },
          { fieldNumber = 3; value = #bool(true) },
        ];
        outputBytes = null;
      },
      {
        bytes = "\0A\02\01\02\12\08\0A\03\6B\65\79\10\E7\07\1A\09\09\1F\85\EB\51\B8\1E\09\40";
        schema = [
          { fieldNumber = 1; valueType = #repeated(#int32) },
          { fieldNumber = 2; valueType = #map((#string, #int32)) },
          {
            fieldNumber = 3;
            valueType = #message([{ fieldNumber = 1; valueType = #double }]);
          },
        ];
        expected = [
          { fieldNumber = 1; value = #repeated([#int32(1), #int32(2)]) },
          { fieldNumber = 2; value = #map([(#string("key"), #int32(999))]) },
          {
            fieldNumber = 3;
            value = #message([{ fieldNumber = 1; value = #double(3.14) }]);
          },
        ];
        outputBytes = null;
      },

      // Edge case: High field numbers
      {
        bytes = "\F8\FF\FF\FF\0F\2A";
        schema = [{ fieldNumber = 536870911; valueType = #int32 }];
        expected = [
          { fieldNumber = 536870911; value = #int32(42) } // Max field number
        ];
        outputBytes = null;
      },
      {
        bytes = "\FA\FF\FF\3F\0A\68\69\67\68\20\66\69\65\6C\64";
        schema = [{ fieldNumber = 16777215; valueType = #string }];
        expected = [
          { fieldNumber = 16777215; value = #string("high field") } // 2^24 - 1
        ];
        outputBytes = null;
      },

      // Edge case: Mixed types with same field number (should combine into repeated)
      // Note: This tests the decoder's ability to handle multiple instances of same field

      // Complex combination
      {
        bytes = "\08\D6\FF\FF\FF\0F\10\FF\FF\FF\FF\FF\FF\FF\FF\FF\01\18\FF\FF\FF\FF\0F\21\FF\FF\FF\FF\FF\FF\FF\7F\2A\11\63\6F\6D\70\6C\65\78\20\74\65\73\74\20\F0\9F\8E\AF\32\04\DE\AD\BE\EF\3A\0C\00\00\80\3F\00\00\00\40\00\00\40\40\42\07\08\01\12\03\6F\6E\65\42\07\08\02\12\03\74\77\6F\4A\05\08\00\10\FF\01";
        schema = [
          { fieldNumber = 1; valueType = #int32 },
          { fieldNumber = 2; valueType = #uint64 },
          { fieldNumber = 3; valueType = #sint32 },
          { fieldNumber = 4; valueType = #fixed64 },
          { fieldNumber = 5; valueType = #string },
          { fieldNumber = 6; valueType = #bytes },
          { fieldNumber = 7; valueType = #repeated(#float) },
          { fieldNumber = 8; valueType = #map((#int32, #string)) },
          {
            fieldNumber = 9;
            valueType = #message([
              { fieldNumber = 1; valueType = #bool },
              { fieldNumber = 2; valueType = #enum },
            ]);
          },
        ];
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
        outputBytes = null;
      },
      // Multiple repeated fields of same type (should merge)
      {
        bytes = "\0A\02\01\02\0A\02\03\04";
        schema = [{ fieldNumber = 1; valueType = #repeated(#int32) }];
        expected = [
          {
            fieldNumber = 1;
            value = #repeated([#int32(1), #int32(2), #int32(3), #int32(4)]);
          },
        ];
        outputBytes = ?"\0A\04\01\02\03\04";
      },

      // Multiple map entries with same field number (should merge)
      {
        bytes = "\0A\08\0A\04\6B\65\79\31\10\01\0A\08\0A\04\6B\65\79\32\10\02";
        schema = [{ fieldNumber = 1; valueType = #map((#string, #int32)) }];
        expected = [{
          fieldNumber = 1;
          value = #map([
            (#string("key1"), #int32(1)),
            (#string("key2"), #int32(2)),
          ]);
        }];
        outputBytes = null;
      },

      // Empty packed repeated field
      {
        bytes = "\0A\00";
        schema = [{ fieldNumber = 1; valueType = #repeated(#int32) }];
        expected = [{
          fieldNumber = 1;
          value = #repeated([]);
        }];
        outputBytes = null;
      },

      // Single element in repeated (non-packed style)
      {
        bytes = "\08\2A";
        schema = [{ fieldNumber = 1; valueType = #repeated(#int32) }];
        expected = [{
          fieldNumber = 1;
          value = #repeated([#int32(42)]);
        }];
        outputBytes = null;
      },

      // Zigzag encoding edge cases
      {
        bytes = "\08\FE\FF\FF\FF\0F";
        schema = [{ fieldNumber = 1; valueType = #sint32 }];
        expected = [{ fieldNumber = 1; value = #sint32(2147483647) }];
        outputBytes = null;
      },
      {
        bytes = "\08\FF\FF\FF\FF\0F";
        schema = [{ fieldNumber = 1; valueType = #sint32 }];
        expected = [{ fieldNumber = 1; value = #sint32(-2147483648) }];
        outputBytes = null;
      },
      {
        bytes = "\08\FE\FF\FF\FF\FF\FF\FF\FF\FF\01";
        schema = [{ fieldNumber = 1; valueType = #sint64 }];
        expected = [{ fieldNumber = 1; value = #sint64(9223372036854775807) }];
        outputBytes = null;
      },

      // Float special values
      {
        bytes = "\0D\00\00\80\7F";
        schema = [{ fieldNumber = 1; valueType = #float }];
        expected = [{ fieldNumber = 1; value = #float(1.0 / 0.0) }]; // +infinity
        outputBytes = null;
      },
      {
        bytes = "\0D\00\00\80\FF";
        schema = [{ fieldNumber = 1; valueType = #float }];
        expected = [{ fieldNumber = 1; value = #float(-1.0 / 0.0) }]; // -infinity
        outputBytes = null;
      },

      // Double special values
      {
        bytes = "\09\00\00\00\00\00\00\F0\7F";
        schema = [{ fieldNumber = 1; valueType = #double }];
        expected = [{ fieldNumber = 1; value = #double(1.0 / 0.0) }]; // +infinity
        outputBytes = null;
      },
      {
        bytes = "\09\00\00\00\00\00\00\F0\FF";
        schema = [{ fieldNumber = 1; valueType = #double }];
        expected = [{ fieldNumber = 1; value = #double(-1.0 / 0.0) }]; // -infinity
        outputBytes = null;
      },

      // Large varint values at boundaries
      {
        bytes = "\08\FF\FF\FF\FF\FF\FF\FF\FF\7F";
        schema = [{ fieldNumber = 1; valueType = #uint64 }];
        expected = [{ fieldNumber = 1; value = #uint64(9223372036854775807) }];
        outputBytes = null;
      },

      // Nested maps
      {
        bytes = "\0A\14\0A\03\6B\65\79\12\0D\0A\06\6E\65\73\74\65\64\12\03\6D\61\70";
        schema = [{
          fieldNumber = 1;
          valueType = #map((#string, #message([{ fieldNumber = 1; valueType = #string }, { fieldNumber = 2; valueType = #string }])));
        }];
        expected = [{
          fieldNumber = 1;
          value = #map([(#string("key"), #message([{ fieldNumber = 1; value = #string("nested") }, { fieldNumber = 2; value = #string("map") }]))]);
        }];
        outputBytes = null;
      },

      // Mixed field types in message
      {
        bytes = "\0A\12\08\01\12\04\74\65\73\74\1D\00\00\20\41\25\AA\18\AF\C9";
        schema = [{
          fieldNumber = 1;
          valueType = #message([
            { fieldNumber = 1; valueType = #bool },
            { fieldNumber = 2; valueType = #string },
            { fieldNumber = 3; valueType = #float },
            { fieldNumber = 4; valueType = #fixed32 },
          ]);
        }];
        expected = [{
          fieldNumber = 1;
          value = #message([
            { fieldNumber = 1; value = #bool(true) },
            { fieldNumber = 2; value = #string("test") },
            { fieldNumber = 3; value = #float(10.0) },
            { fieldNumber = 4; value = #fixed32(3383695530) },
          ]);
        }];
        outputBytes = null;
      },

      // Repeated nested messages
      {
        bytes = "\0A\04\08\01\10\0A\0A\04\08\02\10\14";
        schema = [{
          fieldNumber = 1;
          valueType = #repeated(#message([{ fieldNumber = 1; valueType = #uint32 }, { fieldNumber = 2; valueType = #uint32 }]));
        }];
        expected = [{
          fieldNumber = 1;
          value = #repeated([
            #message([
              { fieldNumber = 1; value = #uint32(1) },
              { fieldNumber = 2; value = #uint32(10) },
            ]),
            #message([
              { fieldNumber = 1; value = #uint32(2) },
              { fieldNumber = 2; value = #uint32(20) },
            ]),
          ]);
        }];
        outputBytes = null;
      },

      // Map with repeated values as map value
      {
        bytes = "\0A\0E\0A\03\6B\65\79\12\07\0A\02\01\02\0A\01\03";
        schema = [{
          fieldNumber = 1;
          valueType = #map((#string, #message([{ fieldNumber = 1; valueType = #repeated(#int32) }])));
        }];
        expected = [{
          fieldNumber = 1;
          value = #map([(#string("key"), #message([{ fieldNumber = 1; value = #repeated([#int32(1), #int32(2), #int32(3)]) }]))]);
        }];
        outputBytes = ?"\0A\0C\0A\03\6B\65\79\12\05\0A\03\01\02\03";
      },

      // Out-of-order fields (decoder should handle)
      {
        bytes = "\18\03\08\01\10\02";
        schema = [
          { fieldNumber = 1; valueType = #uint32 },
          { fieldNumber = 2; valueType = #uint32 },
          { fieldNumber = 3; valueType = #uint32 },
        ];
        expected = [
          { fieldNumber = 1; value = #uint32(1) },
          { fieldNumber = 2; value = #uint32(2) },
          { fieldNumber = 3; value = #uint32(3) },
        ];
        outputBytes = ?"\08\01\10\02\18\03"; // Reordered output
      },

      // Very large field numbers
      {
        bytes = "\80\80\80\80\02\2A"; // Field number 67108864
        schema = [{ fieldNumber = 67108864; valueType = #int32 }];
        expected = [{ fieldNumber = 67108864; value = #int32(42) }];
        outputBytes = null;
      },

      // All numeric types in packed repeated
      {
        bytes = "\0A\06\01\02\03\04\05\06"; // sint32 packed
        schema = [{ fieldNumber = 1; valueType = #repeated(#sint32) }];
        expected = [{
          fieldNumber = 1;
          value = #repeated([
            #sint32(-1),
            #sint32(1),
            #sint32(-2),
            #sint32(2),
            #sint32(-3),
            #sint32(3),
          ]);
        }];
        outputBytes = null;
      },

      // Mixed signed/unsigned in different fields
      {
        bytes = "\08\FF\FF\FF\FF\0F\10\FF\FF\FF\FF\FF\FF\FF\FF\FF\01\18\01\20\FE\FF\FF\FF\0F";
        schema = [
          { fieldNumber = 1; valueType = #uint32 },
          { fieldNumber = 2; valueType = #uint64 },
          { fieldNumber = 3; valueType = #sint32 },
          { fieldNumber = 4; valueType = #sint64 },
        ];
        expected = [
          { fieldNumber = 1; value = #uint32(4294967295) },
          { fieldNumber = 2; value = #uint64(18446744073709551615) },
          { fieldNumber = 3; value = #sint32(-1) },
          { fieldNumber = 4; value = #sint64(2147483647) },
        ];
        outputBytes = null;
      },
      // Block from ICP ledger
      // Canister id : qhbym-qaaaa-aaaaa-aaafq-cai
      // Chain length : 26_399_232
      {
        bytes = "\0a\22\0a\20\ff\ca\0e\cf\5e\83\75\41\c7\ee\5b\e4\31\e4\33\ad\8e\97\2a\7f\37\1e\86\fb\e4\f8\ad\64\6c\7c\bc\ea\12\0a\08\d3\e5\91\b0\de\89\a4\be\16\1a\3d\12\2d\12\22\0a\20\74\ec\82\f5\e0\d8\05\2a\a1\1d\c7\48\24\9b\dd\0a\ec\29\d6\28\19\9e\ee\ef\ad\d0\13\8f\8b\1b\10\59\1a\07\08\ed\e0\d2\df\88\09\22\00\32\0a\08\d3\e5\91\b0\de\89\a4\be\16";
        schema = [
          // Field 1: Hash parent_hash
          {
            fieldNumber = 1;
            valueType = #message([
              { fieldNumber = 1; valueType = #bytes }, // Hash.hash
            ]);
          },
          // Field 2: TimeStamp timestamp
          {
            fieldNumber = 2;
            valueType = #message([
              { fieldNumber = 1; valueType = #uint64 }, // TimeStamp.timestamp_nanos
            ]);
          },
          // Field 3: Transaction transaction
          {
            fieldNumber = 3;
            valueType = #message([
              // Field 1: Burn burn (oneof transfer)
              {
                fieldNumber = 1;
                valueType = #message([
                  {
                    fieldNumber = 1;
                    valueType = #message([
                      { fieldNumber = 1; valueType = #bytes }, // AccountIdentifier.hash
                    ]);
                  }, // Burn.from
                  {
                    fieldNumber = 3;
                    valueType = #message([
                      { fieldNumber = 1; valueType = #uint64 }, // Tokens.e8s
                    ]);
                  }, // Burn.amount
                  {
                    fieldNumber = 4;
                    valueType = #message([
                      { fieldNumber = 1; valueType = #bytes }, // AccountIdentifier.hash
                    ]);
                  }, // Burn.spender
                ]);
              },
              // Field 2: Mint mint (oneof transfer)
              {
                fieldNumber = 2;
                valueType = #message([
                  {
                    fieldNumber = 2;
                    valueType = #message([
                      { fieldNumber = 1; valueType = #bytes }, // AccountIdentifier.hash
                    ]);
                  }, // Mint.to
                  {
                    fieldNumber = 3;
                    valueType = #message([
                      { fieldNumber = 1; valueType = #uint64 }, // Tokens.e8s
                    ]);
                  }, // Mint.amount
                ]);
              },
              // Field 3: Send send (oneof transfer)
              {
                fieldNumber = 3;
                valueType = #message([
                  {
                    fieldNumber = 1;
                    valueType = #message([
                      { fieldNumber = 1; valueType = #bytes }, // AccountIdentifier.hash
                    ]);
                  }, // Send.from
                  {
                    fieldNumber = 2;
                    valueType = #message([
                      { fieldNumber = 1; valueType = #bytes }, // AccountIdentifier.hash
                    ]);
                  }, // Send.to
                  {
                    fieldNumber = 3;
                    valueType = #message([
                      { fieldNumber = 1; valueType = #uint64 }, // Tokens.e8s
                    ]);
                  }, // Send.amount
                  {
                    fieldNumber = 4;
                    valueType = #message([
                      { fieldNumber = 1; valueType = #uint64 }, // Tokens.e8s
                    ]);
                  }, // Send.max_fee
                  // Field 5: Approve approve (oneof extension)
                  {
                    fieldNumber = 5;
                    valueType = #message([
                      {
                        fieldNumber = 1;
                        valueType = #message([
                          { fieldNumber = 1; valueType = #uint64 }, // Tokens.e8s
                        ]);
                      }, // Approve.allowance
                      {
                        fieldNumber = 2;
                        valueType = #message([
                          { fieldNumber = 1; valueType = #uint64 }, // TimeStamp.timestamp_nanos
                        ]);
                      }, // Approve.expires_at
                      {
                        fieldNumber = 3;
                        valueType = #message([
                          { fieldNumber = 1; valueType = #uint64 }, // Tokens.e8s
                        ]);
                      }, // Approve.expected_allowance
                    ]);
                  },
                  // Field 6: TransferFrom transfer_from (oneof extension)
                  {
                    fieldNumber = 6;
                    valueType = #message([
                      {
                        fieldNumber = 1;
                        valueType = #message([
                          { fieldNumber = 1; valueType = #bytes }, // AccountIdentifier.hash
                        ]);
                      }, // TransferFrom.spender
                    ]);
                  },
                ]);
              },
              // Field 4: Memo memo
              {
                fieldNumber = 4;
                valueType = #message([
                  { fieldNumber = 1; valueType = #uint64 }, // Memo.memo
                ]);
              },
              // Field 5: BlockIndex created_at (obsolete)
              {
                fieldNumber = 5;
                valueType = #message([
                  { fieldNumber = 1; valueType = #uint64 }, // BlockIndex.height
                ]);
              },
              // Field 6: TimeStamp created_at_time
              {
                fieldNumber = 6;
                valueType = #message([
                  { fieldNumber = 1; valueType = #uint64 }, // TimeStamp.timestamp_nanos
                ]);
              },
              // Field 7: Icrc1Memo icrc1_memo
              {
                fieldNumber = 7;
                valueType = #message([
                  { fieldNumber = 1; valueType = #bytes }, // Icrc1Memo.memo
                ]);
              },
            ]);
          },
        ];
        expected = [
          {
            fieldNumber = 1;
            value = #message([{
              fieldNumber = 1;
              value = #bytes([255, 202, 14, 207, 94, 131, 117, 65, 199, 238, 91, 228, 49, 228, 51, 173, 142, 151, 42, 127, 55, 30, 134, 251, 228, 248, 173, 100, 108, 124, 188, 234]);
            }]);
          },
          {
            fieldNumber = 2;
            value = #message([{
              fieldNumber = 1;
              value = #uint64(1_620_328_630_192_468_691);
            }]);
          },
          {
            fieldNumber = 3;
            value = #message([{ fieldNumber = 2; value = #message([{ fieldNumber = 2; value = #message([{ fieldNumber = 1; value = #bytes([116, 236, 130, 245, 224, 216, 5, 42, 161, 29, 199, 72, 36, 155, 221, 10, 236, 41, 214, 40, 25, 158, 238, 239, 173, 208, 19, 143, 139, 27, 16, 89]) }]) }, { fieldNumber = 3; value = #message([{ fieldNumber = 1; value = #uint64(311_585_714_285) }]) }]) }, { fieldNumber = 4; value = #message([]) }, { fieldNumber = 6; value = #message([{ fieldNumber = 1; value = #uint64(1_620_328_630_192_468_691) }]) }]);
          },
        ];
        outputBytes = null;
      }

    ];

    func test(testCase : TestCase) : Result.Result<(), Text> {

      let rawFields = switch (Protobuf.fromRawBytes(testCase.bytes.vals())) {
        case (#err(e)) return #err("Decoding raw fields failed: " # e);
        case (#ok(rawFields)) rawFields;
      };

      switch (Protobuf.fromRawFields(rawFields, testCase.schema)) {
        case (#err(e)) return #err("Decoding failed: " # e);
        case (#ok(decodedFields)) {
          if (decodedFields != testCase.expected) {
            return #err("Decoded fields do not match expected.\nExpected: " # debug_show (testCase.expected) # "\nActual:   " # debug_show (decodedFields));
          };
        };
      };

      let actualBytes = switch (Protobuf.toBytes(testCase.expected)) {
        case (#err(e)) return #err("Encoding failed: " # e);
        case (#ok(actualBytes)) Blob.fromArray(actualBytes);
      };

      let outputBytes = switch (testCase.outputBytes) {
        case (null) testCase.bytes;
        case (?outputBytes) outputBytes;
      };

      if (actualBytes != outputBytes) {
        return #err("Invalid encoded bytes.\nExpected: " # debug_show (outputBytes) # "\nActual:   " # debug_show (actualBytes) # "\nMessage: " # debug_show (testCase.expected));
      };

      #ok;
    };

    let failures = List.empty<Text>();
    for (testCase in testCases.vals()) {
      switch (test(testCase)) {
        case (#ok) ();
        case (#err(e)) List.add(failures, e);
      };
    };
    if (not List.isEmpty(failures)) {
      Debug.trap("Some tests failed:\n" # Text.join("\n---\n", List.values(failures)));
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

    // Test invalid field number (too large)
    let fieldNumberTooLarge = Protobuf.toBytes([{
      fieldNumber = 536870912; // 2^29, exceeds max
      value = #uint64(1);
    }]);
    switch (fieldNumberTooLarge) {
      case (#err(errorText)) {
        if (errorText.size() == 0) {
          Debug.trap("Expected non-empty error message for field number too large");
        };
      };
      case (#ok(result)) Debug.trap("Expected error for field number too large, got: " # debug_show (result));
    };

    // Test invalid UTF-8 in string decoding
    let invalidUtf8 = Protobuf.fromBytes(
      Blob.fromArray([0x0A : Nat8, 0x02, 0xFF, 0xFE]).vals(), // Invalid UTF-8 sequence
      [{ fieldNumber = 1; valueType = #string }],
    );
    switch (invalidUtf8) {
      case (#err(errorText)) {
        if (errorText.size() == 0) {
          Debug.trap("Expected non-empty error message for invalid UTF-8");
        };
      };
      case (#ok(result)) Debug.trap("Expected error for invalid UTF-8, got: " # debug_show (result));
    };

    // Test truncated length-delimited field
    let truncatedLength = Protobuf.fromRawBytes(
      Blob.fromArray([0x0A : Nat8, 0x05, 0x01, 0x02]).vals() // Says length 5 but only 2 bytes follow
    );
    switch (truncatedLength) {
      case (#err(errorText)) {
        if (errorText.size() == 0) {
          Debug.trap("Expected non-empty error message for truncated length-delimited");
        };
      };
      case (#ok(result)) Debug.trap("Expected error for truncated length-delimited, got: " # debug_show (result));
    };

    // Test incomplete varint
    let incompleteVarint = Protobuf.fromRawBytes(
      Blob.fromArray([0x08 : Nat8, 0xFF, 0xFF]).vals() // Varint missing continuation
    );
    switch (incompleteVarint) {
      case (#err(errorText)) {
        if (errorText.size() == 0) {
          Debug.trap("Expected non-empty error message for incomplete varint");
        };
      };
      case (#ok(result)) Debug.trap("Expected error for incomplete varint, got: " # debug_show (result));
    };

    // Test invalid bool value (> 1)
    let invalidBool = Protobuf.fromBytes(
      Blob.fromArray([0x08 : Nat8, 0x02]).vals(), // Bool with value 2
      [{ fieldNumber = 1; valueType = #bool }],
    );
    switch (invalidBool) {
      case (#err(errorText)) {
        if (errorText.size() == 0) {
          Debug.trap("Expected non-empty error message for invalid bool");
        };
      };
      case (#ok(result)) Debug.trap("Expected error for invalid bool, got: " # debug_show (result));
    };

    // Test varint overflow for uint32
    let uint32Overflow = Protobuf.fromBytes(
      Blob.fromArray([0x08 : Nat8, 0x80, 0x80, 0x80, 0x80, 0x10]).vals(), // Value > uint32 max
      [{ fieldNumber = 1; valueType = #uint32 }],
    );
    switch (uint32Overflow) {
      case (#err(errorText)) {
        if (errorText.size() == 0) {
          Debug.trap("Expected non-empty error message for uint32 overflow");
        };
      };
      case (#ok(result)) Debug.trap("Expected error for uint32 overflow, got: " # debug_show (result));
    };

    // Test insufficient bytes for fixed32
    let insufficientFixed32 = Protobuf.fromRawBytes(
      Blob.fromArray([0x0D : Nat8, 0x01, 0x02]).vals() // Fixed32 needs 4 bytes, only 2 provided
    );
    switch (insufficientFixed32) {
      case (#err(errorText)) {
        if (errorText.size() == 0) {
          Debug.trap("Expected non-empty error message for insufficient fixed32 bytes");
        };
      };
      case (#ok(result)) Debug.trap("Expected error for insufficient fixed32 bytes, got: " # debug_show (result));
    };

    // Test insufficient bytes for fixed64
    let insufficientFixed64 = Protobuf.fromRawBytes(
      Blob.fromArray([0x09 : Nat8, 0x01, 0x02, 0x03]).vals() // Fixed64 needs 8 bytes, only 3 provided
    );
    switch (insufficientFixed64) {
      case (#err(errorText)) {
        if (errorText.size() == 0) {
          Debug.trap("Expected non-empty error message for insufficient fixed64 bytes");
        };
      };
      case (#ok(result)) Debug.trap("Expected error for insufficient fixed64 bytes, got: " # debug_show (result));
    };

    // Test unknown field in schema
    let unknownField = Protobuf.fromBytes(
      Blob.fromArray([0x10 : Nat8, 0x01]).vals(), // Field number 2
      [{ fieldNumber = 1; valueType = #uint32 }] // Schema only defines field 1
    );
    switch (unknownField) {
      case (#err(errorText)) {
        if (errorText.size() == 0) {
          Debug.trap("Expected non-empty error message for unknown field");
        };
      };
      case (#ok(result)) Debug.trap("Expected error for unknown field, got: " # debug_show (result));
    };

    // Test invalid map entry (wrong number of fields)
    let invalidMapEntry = Protobuf.fromBytes(
      Blob.fromArray([0x0A : Nat8, 0x02, 0x08, 0x01]).vals(), // Map entry with only key, no value
      [{ fieldNumber = 1; valueType = #map((#uint32, #uint32)) }],
    );
    switch (invalidMapEntry) {
      case (#err(errorText)) {
        if (errorText.size() == 0) {
          Debug.trap("Expected non-empty error message for invalid map entry");
        };
      };
      case (#ok(result)) Debug.trap("Expected error for invalid map entry, got: " # debug_show (result));
    };

    // Test mixed types in repeated field (should fail validation)
    let mixedRepeated = Protobuf.toBytes([{
      fieldNumber = 1;
      value = #repeated([#int32(1), #string("invalid")]);
    }]);
    switch (mixedRepeated) {
      case (#err(errorText)) {
        if (errorText.size() == 0) {
          Debug.trap("Expected non-empty error message for mixed repeated types");
        };
      };
      case (#ok(result)) Debug.trap("Expected error for mixed repeated types, got: " # debug_show (result));
    };
  },
);
