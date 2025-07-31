# Motoko Protocol Buffer Encoder/Decoder

[![MOPS](https://img.shields.io/badge/MOPS-protobuf-blue)](https://mops.one/protobuf)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/edjCase/motoko_protobuf/blob/main/LICENSE)

A Motoko library for encoding and decoding Protocol Buffer (protobuf) messages. This library provides functionality to serialize structured data into binary format and deserialize it back to structured data following the protobuf specification.

## Package

### MOPS

```bash
mops add protobuf
```

To set up MOPS package manager, follow the instructions from the [MOPS Site](https://mops.one)

## Quick Start

### Example 1: Basic Message Encoding

```motoko
import Protobuf "mo:protobuf";
import Result "mo:core/Result";
import Debug "mo:core/Debug";

// Create a simple message with multiple field types
let fields = [
  { fieldNumber = 1; value = #string("Hello World") },
  { fieldNumber = 2; value = #int32(42) },
  { fieldNumber = 3; value = #bool(true) }
];

// Encode to bytes
switch (Protobuf.toBytes(fields)) {
  case (#ok(bytes)) {
    Debug.print("Encoded: " # debug_show(bytes));
  };
  case (#err(error)) {
    Debug.print("Encoding error: " # error);
  };
};
```

### Example 2: Basic Decoding

```motoko
import Protobuf "mo:protobuf";
import Result "mo:core/Result";
import Debug "mo:core/Debug";

// Define the expected message schema
let schema = [
  { fieldNumber = 1; valueType = #string },
  { fieldNumber = 2; valueType = #int32 },
  { fieldNumber = 3; valueType = #bool }
];

// Decode protobuf bytes with schema validation
let bytes : [Nat8] = [/* protobuf binary data */];
switch (Protobuf.fromBytes(bytes.vals(), schema)) {
  case (#ok(fields)) {
    Debug.print("Decoded fields: " # debug_show(fields));
  };
  case (#err(error)) {
    Debug.print("Decoding error: " # error);
  };
};
```

### Example 3: Decoding without schema

```motoko
import Protobuf "mo:protobuf";

// Parse raw protobuf data without schema
let bytes : [Nat8] = [/* protobuf binary data */];
switch (Protobuf.fromRawBytes(bytes.vals())) {
  case (#ok(rawFields)) {
    // Process raw fields - useful for unknown message types
    for (field in rawFields.vals()) {
      Debug.print("Field " # debug_show(field.fieldNumber) #
                 " with wire type " # debug_show(field.wireType));
    };
  };
  case (#err(error)) {
    Debug.print("Parsing error: " # error);
  };
};
```

### Example 4: Buffer-based Encoding

```motoko
import Protobuf "mo:protobuf";
import Buffer "mo:buffer";

// Use buffer for efficient encoding
let list = List.empty<Nat8>();
let buffer = Buffer.fromList<Nat8>(list);
let fields = [
  { fieldNumber = 1; value = #string("Efficient encoding") },
  { fieldNumber = 2; value = #uint64(9876543210) }
];

switch (Protobuf.toBytesBuffer(buffer, fields)) {
  case (#ok(bytesWritten)) {
    Debug.print("Wrote " # debug_show(bytesWritten) # " bytes");
  };
  case (#err(error)) {
    Debug.print("Error: " # error);
  };
};
```

## Supported Data Types

### Primitive Types

- **Integers**: `int32`, `int64`, `uint32`, `uint64`, `sint32`, `sint64`
- **Floating Point**: `float` (32-bit), `double` (64-bit)
- **Boolean**: `bool`
- **Enumerations**: `enum`

### Variable-Length Types

- **Text**: `string` (UTF-8 encoded)
- **Binary Data**: `bytes`

### Complex Types

- **Nested Messages**: `message`
- **Arrays**: `repeated` (supports packed encoding for primitives)
- **Key-Value Maps**: `map`

### Fixed-Length Types

- **Fixed Integers**: `fixed32`, `fixed64`, `sfixed32`, `sfixed64`

## Use Cases

• **Microservices Communication**: Efficient data exchange between services
• **Data Serialization**: Compact storage and transmission of structured data
• **API Protocols**: Language-agnostic message formats
• **Configuration Files**: Structured configuration with schema validation
• **Blockchain Data**: Efficient encoding of transaction and state data
• **Inter-Canister Communication**: Optimized data transfer on Internet Computer

## API Reference

### Core Types

```motoko
// A protobuf field with number and typed value
public type Field = {
  fieldNumber : Nat;
  value : Value;
};

// Schema definition for field validation
public type FieldType = {
  fieldNumber : Nat;
  valueType : ValueType;
};

// All possible protobuf values
public type Value = /* Union of all value types */;

// Type indicators for schema definitions
public type ValueType = /* Union of all type indicators */;
```

### Encoding Functions

```motoko
// Encode protobuf fields to byte array
public func toBytes(message : [Field]) : Result.Result<[Nat8], Text>;

// Encode protobuf fields to buffer (more efficient)
public func toBytesBuffer(
  buffer : Buffer.Buffer<Nat8>,
  message : [Field]
) : Result.Result<Nat, Text>;
```

### Decoding Functions

```motoko
// Decode bytes to typed fields using schema
public func fromBytes(
  bytes : Iter.Iter<Nat8>,
  schema : [FieldType]
) : Result.Result<[Field], Text>;

// Decode bytes to raw fields (no schema required)
public func fromRawBytes(
  bytes : Iter.Iter<Nat8>
) : Result.Result<[RawField], Text>;

// Convert raw fields to typed fields using schema
public func fromRawFields(
  rawFields : [RawField],
  schema : [FieldType]
) : Result.Result<[Field], Text>;
```

## Testing

```bash
mops test
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
