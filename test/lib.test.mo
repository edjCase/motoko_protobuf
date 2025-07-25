import Protobuf "../src";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Nat8 "mo:base/Nat8";
import { test } "mo:test";
import Blob "mo:new-base/Blob";

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
    ];

    for (testCase in testCases.vals()) {
      let decodeResult = Protobuf.fromRawBytes(testCase.bytes.vals());
      let rawFields = trapOrReturn<[Protobuf.RawField], Text>(decodeResult, func(e) { e });

      // Convert raw fields to expected format for comparison (simplified test)
      let actualCount = rawFields.size();
      let expectedCount = testCase.expected.size();

      if (actualCount != expectedCount) {
        Debug.trap("Invalid decoded message count.\nExpected: " # debug_show (testCase.expected) # "\nActual: " # debug_show (rawFields) # "\nBytes: " # debug_show (testCase.bytes));
      };

      let encodeResult = Protobuf.toBytes(testCase.expected);
      let actualBytes = Blob.fromArray(trapOrReturn<[Nat8], Text>(encodeResult, func(e) { e }));

      if (actualBytes != testCase.bytes) {
        Debug.trap("Invalid encoded bytes.\nExpected: " # debug_show (testCase.bytes) # "\nActual:   " # debug_show (actualBytes) # "\nMessage: " # debug_show (testCase.expected));
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
