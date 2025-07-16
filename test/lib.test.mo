import Protobuf "../src";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Int32 "mo:base/Int32";
import Int64 "mo:base/Int64";
import Char "mo:base/Char";
import { test } "mo:test";

func testBytes(bytes : [Nat8], expected : Protobuf.Message, reverseBytes : ?[Nat8]) {
  let decodeResult = Protobuf.decode(bytes.vals());
  let actual : Protobuf.Message = trapOrReturn<Protobuf.Message, Protobuf.DecodingError>(decodeResult, func(e) { debug_show (e) });

  if (actual != expected) {
    Debug.trap("Invalid decoded message.\nExpected: " # debug_show (expected) # "\nActual: " # debug_show (actual) # "\nBytes: " # toHexString(bytes));
  };

  let encodeResult = Protobuf.encode(actual);
  let actualBytes = trapOrReturn<[Nat8], Protobuf.EncodingError>(encodeResult, func(e) { debug_show (e) });
  let comparisonBytes : [Nat8] = switch (reverseBytes) {
    case (null) bytes;
    case (?v) v;
  };

  if (actualBytes != comparisonBytes) {
    Debug.trap("Invalid encoded bytes.\nExpected: " # toHexString(comparisonBytes) # "\nActual:   " # toHexString(actualBytes) # "\nMessage: " # debug_show (actual));
  };
};

func testField(bytes : [Nat8], expected : Protobuf.Field) {
  let decodeResult = Protobuf.decode(bytes.vals());
  let message = trapOrReturn<Protobuf.Message, Protobuf.DecodingError>(decodeResult, func(e) { debug_show (e) });

  if (message.size() != 1) {
    Debug.trap("Expected single field, got " # debug_show (message.size()) # " fields");
  };

  let actual = message[0];
  if (actual != expected) {
    Debug.trap("Invalid field.\nExpected: " # debug_show (expected) # "\nActual: " # debug_show (actual));
  };

  let encodeResult = Protobuf.encodeField(actual);
  let actualBytes = trapOrReturn<[Nat8], Protobuf.EncodingError>(encodeResult, func(e) { debug_show (e) });

  if (actualBytes != bytes) {
    Debug.trap("Invalid field bytes.\nExpected: " # toHexString(bytes) # "\nActual:   " # toHexString(actualBytes));
  };
};

func trapOrReturn<TValue, TErr>(result : Result.Result<TValue, TErr>, show : (TErr) -> Text) : TValue {
  switch (result) {
    case (#err(e)) Debug.trap("Error: " # show(e));
    case (#ok(a)) a;
  };
};

func toHexString(array : [Nat8]) : Text {
  Array.foldLeft<Nat8, Text>(
    array,
    "",
    func(accum, w8) {
      var pre = "";
      if (accum != "") {
        pre #= ", ";
      };
      accum # pre # encodeW8(w8);
    },
  );
};

let base : Nat8 = 0x10;
let symbols = [
  '0',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
];

func encodeW8(w8 : Nat8) : Text {
  let c1 = symbols[Nat8.toNat(w8 / base)];
  let c2 = symbols[Nat8.toNat(w8 % base)];
  "0x" # Char.toText(c1) # Char.toText(c2);
};

test(
  "Varint Encoding - Basic",
  func() {
    // Field 1, varint 0
    testField([0x08, 0x00], { fieldNumber = 1; wireType = #varint; value = #uint64(0) });

    // Field 1, varint 1
    testField([0x08, 0x01], { fieldNumber = 1; wireType = #varint; value = #uint64(1) });

    // Field 1, varint 127 (single byte max)
    testField([0x08, 0x7F], { fieldNumber = 1; wireType = #varint; value = #uint64(127) });

    // Field 1, varint 128 (requires continuation)
    testField([0x08, 0x80, 0x01], { fieldNumber = 1; wireType = #varint; value = #uint64(128) });

    // Field 1, varint 150
    testField([0x08, 0x96, 0x01], { fieldNumber = 1; wireType = #varint; value = #uint64(150) });

    // Field 1, varint 16384
    testField([0x08, 0x80, 0x80, 0x01], { fieldNumber = 1; wireType = #varint; value = #uint64(16384) });
  },
);

test(
  "Varint Encoding - Large Numbers",
  func() {
    // Field 1, varint 1000000
    testField([0x08, 0xC0, 0x84, 0x3D], { fieldNumber = 1; wireType = #varint; value = #uint64(1000000) });

    // Field 1, varint max uint32
    testField([0x08, 0xFF, 0xFF, 0xFF, 0xFF, 0x0F], { fieldNumber = 1; wireType = #varint; value = #uint64(4294967295) });

    // Field 1, varint large 64-bit
    testField([0x08, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F], { fieldNumber = 1; wireType = #varint; value = #uint64(9223372036854775807) });
  },
);

test(
  "Field Numbers",
  func() {
    // Field 15, varint 1 (single byte tag)
    testField([0x78, 0x01], { fieldNumber = 15; wireType = #varint; value = #uint64(1) });

    // Field 16, varint 1 (two byte tag)
    testField([0x80, 0x01, 0x01], { fieldNumber = 16; wireType = #varint; value = #uint64(1) });

    // Field 100, varint 1
    testField([0xA0, 0x06, 0x01], { fieldNumber = 100; wireType = #varint; value = #uint64(1) });

    // Field 1000, varint 1
    testField([0xC0, 0x3E, 0x01], { fieldNumber = 1000; wireType = #varint; value = #uint64(1) });
  },
);

test(
  "Length-Delimited - Strings",
  func() {
    // Field 2, string ""
    testField([0x12, 0x00], { fieldNumber = 2; wireType = #lengthDelimited; value = #string("") });

    // Field 2, string "test"
    testField([0x12, 0x04, 0x74, 0x65, 0x73, 0x74], { fieldNumber = 2; wireType = #lengthDelimited; value = #string("test") });

    // Field 2, string "hello"
    testField([0x12, 0x05, 0x68, 0x65, 0x6C, 0x6C, 0x6F], { fieldNumber = 2; wireType = #lengthDelimited; value = #string("hello") });

    // Field 2, string "Protocol Buffers"
    testField(
      [0x12, 0x10, 0x50, 0x72, 0x6F, 0x74, 0x6F, 0x63, 0x6F, 0x6C, 0x20, 0x42, 0x75, 0x66, 0x66, 0x65, 0x72, 0x73],
      {
        fieldNumber = 2;
        wireType = #lengthDelimited;
        value = #string("Protocol Buffers");
      },
    );
  },
);

test(
  "Length-Delimited - Bytes",
  func() {
    // Field 3, bytes []
    testField([0x1A, 0x00], { fieldNumber = 3; wireType = #lengthDelimited; value = #bytes([]) });

    // Field 3, bytes [0x01, 0x02, 0x03]
    testField([0x1A, 0x03, 0x01, 0x02, 0x03], { fieldNumber = 3; wireType = #lengthDelimited; value = #bytes([0x01, 0x02, 0x03]) });

    // Field 3, bytes [0xFF, 0x00, 0xAA, 0x55]
    testField([0x1A, 0x04, 0xFF, 0x00, 0xAA, 0x55], { fieldNumber = 3; wireType = #lengthDelimited; value = #bytes([0xFF, 0x00, 0xAA, 0x55]) });
  },
);

test(
  "Fixed32",
  func() {
    // Field 4, fixed32 0
    testField([0x25, 0x00, 0x00, 0x00, 0x00], { fieldNumber = 4; wireType = #fixed32; value = #fixed32(0) });

    // Field 4, fixed32 1
    testField([0x25, 0x01, 0x00, 0x00, 0x00], { fieldNumber = 4; wireType = #fixed32; value = #fixed32(1) });

    // Field 4, fixed32 0x12345678
    testField([0x25, 0x78, 0x56, 0x34, 0x12], { fieldNumber = 4; wireType = #fixed32; value = #fixed32(0x12345678) });

    // Field 4, fixed32 max uint32
    testField([0x25, 0xFF, 0xFF, 0xFF, 0xFF], { fieldNumber = 4; wireType = #fixed32; value = #fixed32(4294967295) });
  },
);

test(
  "Fixed64",
  func() {
    // Field 5, fixed64 0
    testField([0x29, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], { fieldNumber = 5; wireType = #fixed64; value = #fixed64(0) });

    // Field 5, fixed64 1
    testField([0x29, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], { fieldNumber = 5; wireType = #fixed64; value = #fixed64(1) });

    // Field 5, fixed64 0x123456789ABCDEF0
    testField([0x29, 0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12], { fieldNumber = 5; wireType = #fixed64; value = #fixed64(0x123456789ABCDEF0) });
  },
);

test(
  "Multiple Fields",
  func() {
    // Message with field 1 (varint 150) and field 2 (string "test")
    testBytes(
      [0x08, 0x96, 0x01, 0x12, 0x04, 0x74, 0x65, 0x73, 0x74],
      [
        { fieldNumber = 1; wireType = #varint; value = #uint64(150) },
        {
          fieldNumber = 2;
          wireType = #lengthDelimited;
          value = #string("test");
        },
      ],
      null,
    );

    // Message with three fields of different types
    testBytes(
      [0x08, 0x2A, 0x12, 0x05, 0x68, 0x65, 0x6C, 0x6C, 0x6F, 0x25, 0x78, 0x56, 0x34, 0x12],
      [
        { fieldNumber = 1; wireType = #varint; value = #uint64(42) },
        {
          fieldNumber = 2;
          wireType = #lengthDelimited;
          value = #string("hello");
        },
        { fieldNumber = 4; wireType = #fixed32; value = #fixed32(0x12345678) },
      ],
      null,
    );

    // Empty message
    testBytes([], [], null);
  },
);

test(
  "UTF-8 Strings",
  func() {
    // Field 2, UTF-8 "café"
    testField([0x12, 0x05, 0x63, 0x61, 0x66, 0xC3, 0xA9], { fieldNumber = 2; wireType = #lengthDelimited; value = #string("café") });

    // Field 2, UTF-8 "🚀"
    testField([0x12, 0x04, 0xF0, 0x9F, 0x9A, 0x80], { fieldNumber = 2; wireType = #lengthDelimited; value = #string("🚀") });

    // Field 2, UTF-8 "こんにちは"
    testField(
      [0x12, 0x0F, 0xE3, 0x81, 0x93, 0xE3, 0x82, 0x93, 0xE3, 0x81, 0xAB, 0xE3, 0x81, 0xA1, 0xE3, 0x81, 0xAF],
      {
        fieldNumber = 2;
        wireType = #lengthDelimited;
        value = #string("こんにちは");
      },
    );
  },
);

test(
  "Zigzag Decoding",
  func() {
    // Test zigzag decoding helper functions
    assert (Protobuf.zigzagDecode32(0) == 0);
    assert (Protobuf.zigzagDecode32(1) == -1);
    assert (Protobuf.zigzagDecode32(2) == 1);
    assert (Protobuf.zigzagDecode32(3) == -2);
    assert (Protobuf.zigzagDecode32(4) == 2);

    assert (Protobuf.zigzagDecode64(0) == 0);
    assert (Protobuf.zigzagDecode64(1) == -1);
    assert (Protobuf.zigzagDecode64(2) == 1);
    assert (Protobuf.zigzagDecode64(3) == -2);
    assert (Protobuf.zigzagDecode64(4) == 2);
  },
);

test(
  "Float Conversion",
  func() {
    // Test basic float conversion helper functions
    assert (Protobuf.bitsToFloat32(0) == 0.0);
    assert (Protobuf.bitsToFloat32(0x3f800000) == 1.0);
    assert (Protobuf.bitsToFloat32(0xbf800000) == -1.0);

    assert (Protobuf.bitsToFloat64(0) == 0.0);
    assert (Protobuf.bitsToFloat64(0x3ff0000000000000) == 1.0);
    assert (Protobuf.bitsToFloat64(0xbff0000000000000) == -1.0);
  },
);

test(
  "Error Handling",
  func() {
    // Test invalid wire type
    let invalidWireType = Protobuf.decode([0x0B].vals()); // Wire type 3 (start_group) not supported
    switch (invalidWireType) {
      case (#err(#invalidWireType(3))) {}; // Expected
      case (result) Debug.trap("Expected invalidWireType error, got: " # debug_show (result));
    };

    // Test unexpected end of bytes
    let truncated = Protobuf.decode([0x08].vals()); // Tag without value
    switch (truncated) {
      case (#err(#unexpectedEndOfBytes)) {}; // Expected
      case (result) Debug.trap("Expected unexpectedEndOfBytes error, got: " # debug_show (result));
    };

    // Test invalid field number (0)
    let invalidField = Protobuf.encodeField({
      fieldNumber = 0;
      wireType = #varint;
      value = #uint64(1);
    });
    switch (invalidField) {
      case (#err(#invalidFieldNumber)) {}; // Expected
      case (result) Debug.trap("Expected invalidFieldNumber error, got: " # debug_show (result));
    };
  },
);

test(
  "Complex Message",
  func() {
    // Test a more complex message with various field types
    let complexMessage : Protobuf.Message = [
      { fieldNumber = 1; wireType = #varint; value = #uint64(42) },
      {
        fieldNumber = 2;
        wireType = #lengthDelimited;
        value = #string("hello world");
      },
      {
        fieldNumber = 3;
        wireType = #lengthDelimited;
        value = #bytes([0xDE, 0xAD, 0xBE, 0xEF]);
      },
      { fieldNumber = 4; wireType = #fixed32; value = #fixed32(0x12345678) },
      {
        fieldNumber = 5;
        wireType = #fixed64;
        value = #fixed64(0x123456789ABCDEF0);
      },
      { fieldNumber = 100; wireType = #varint; value = #uint64(9999) },
    ];

    let encoded = trapOrReturn<[Nat8], Protobuf.EncodingError>(Protobuf.encode(complexMessage), func(e) { debug_show (e) });
    let decoded = trapOrReturn<Protobuf.Message, Protobuf.DecodingError>(Protobuf.decode(encoded.vals()), func(e) { debug_show (e) });

    if (decoded != complexMessage) {
      Debug.trap("Complex message round-trip failed");
    };
  },
);

test(
  "Edge Cases",
  func() {
    // Very large field number (within valid range)
    testField([0xF8, 0xFF, 0xFF, 0xFF, 0x0F, 0x01], { fieldNumber = 536870911; wireType = #varint; value = #uint64(1) });

    // Large varint
    testField([0x08, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01], { fieldNumber = 1; wireType = #varint; value = #uint64(18446744073709551615) });

    // Empty string vs empty bytes (both decode to their respective types)
    testField([0x12, 0x00], { fieldNumber = 2; wireType = #lengthDelimited; value = #string("") });
    testField([0x1A, 0x00], { fieldNumber = 3; wireType = #lengthDelimited; value = #bytes([]) });
  },
);
