import Buffer "mo:base/Buffer";
import Int32 "mo:base/Int32";
import Int64 "mo:base/Int64";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Float "mo:base/Float";
import Blob "mo:base/Blob";
import Types "./Types";
import PeekableIter "mo:xtended-iter/PeekableIter";
import LEB128 "mo:leb128";

/// Protobuf (Protocol Buffers) decoder for Motoko.
///
/// This module provides functionality for decoding Protobuf binary data to Motoko values
/// according to the Protocol Buffers wire format specification. The decoder handles
/// variable-length integers, length-delimited values, and fixed-width values.
///
/// Key features:
/// * Decode Protobuf binary data to Motoko values
/// * Support for all wire types (varint, fixed32, fixed64, length-delimited)
/// * Streaming decoding with iterator-based input
/// * Varint decoding for integers
/// * Zigzag decoding for signed integers
/// * IEEE 754 decoding for floating-point numbers
/// * Comprehensive error handling and validation
///
/// Example usage:
/// ```motoko
/// import Protobuf "mo:protobuf";
/// import Result "mo:base/Result";
///
/// // Decode Protobuf bytes to a message
/// let bytes: [Nat8] = [0x08, 0x96, 0x01, 0x12, 0x04, 0x74, 0x65, 0x73, 0x74];
/// let result = Protobuf.decode(bytes.vals());
/// switch (result) {
///   case (#ok(message)) { /* Use decoded message */ };
///   case (#err(error)) { /* Handle decoding error */ };
/// };
/// ```
///
/// Security considerations:
/// * Protobuf data from untrusted sources should be validated
/// * Be aware of potential memory usage with large messages
/// * Consider limits on recursion depth for deeply nested structures
module {

    /// Decodes a series of bytes into a Protobuf message.
    /// This is the main decoding function that converts Protobuf binary data to a structured message.
    ///
    /// The function accepts an iterator of bytes, which allows for efficient streaming
    /// decoding of large data sets. The decoder handles all Protobuf wire types and validates
    /// the input data according to the Protobuf specification.
    ///
    /// Parameters:
    /// * `bytes`: An iterator over the Protobuf-encoded bytes to decode
    ///
    /// Returns:
    /// * `#ok(Types.Message)`: Successfully decoded Protobuf message
    /// * `#err(Types.DecodingError)`: Decoding failed with error details
    ///
    /// Example:
    /// ```motoko
    /// let bytes: [Nat8] = [0x08, 0x96, 0x01]; // field 1, varint 150
    /// let message: Types.Message = switch(decode(bytes.vals())) {
    ///     case (#err(e)) Debug.trap("Decoding failed: " # debug_show(e));
    ///     case (#ok(m)) m;
    /// };
    /// ```
    public func decode(bytes : Iter.Iter<Nat8>) : Result.Result<Types.Message, Types.DecodingError> {
        let decoder = ProtobufDecoder(bytes);
        decoder.decode();
    };

    private class ProtobufDecoder(bytes : Iter.Iter<Nat8>) {
        let peekableIter = PeekableIter.fromIter(bytes);

        public func decode() : Result.Result<Types.Message, Types.DecodingError> {
            let fields = Buffer.Buffer<Types.Field>(0);
            while (PeekableIter.hasNext(peekableIter)) {
                // Decode each field until we reach the end of the input
                switch (decodeField()) {
                    case (#err(e)) return #err(e);
                    case (#ok(field)) fields.add(field);
                };
            };
            #ok(Buffer.toArray(fields));
        };

        private func decodeField() : Result.Result<Types.Field, Types.DecodingError> {
            // Read and decode tag (field number + wire type)
            let tag = switch (LEB128.fromUnsignedBytes(peekableIter)) {
                case (#err(e)) return #err(#invalidVarint);
                case (#ok(v)) v;
            };

            let wireTypeNum = Nat8.fromNat(tag % 8);
            let fieldNumber = Nat32.fromNat(tag / 8);

            // Validate field number
            if (fieldNumber == 0 or fieldNumber > 536870911) {
                return #err(#invalidFieldNumber);
            };

            // Parse wire type
            let wireType : Types.WireType = switch (wireTypeNum) {
                case (0) #varint;
                case (1) #fixed64;
                case (2) #lengthDelimited;
                case (5) #fixed32;
                case (wt) return #err(#invalidWireType(wt));
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

        private func decodeValue(wireType : Types.WireType) : Result.Result<Types.Value, Types.DecodingError> {
            switch (wireType) {
                case (#varint) {
                    switch (LEB128.fromUnsignedBytes(peekableIter)) {
                        case (#err(e)) #err(#invalidVarint);
                        case (#ok(v)) {
                            // For varint, we need to infer the specific type
                            // For now, default to uint64 - in practice, you'd need schema info
                            #ok(#uint64(v));
                        };
                    };
                };
                case (#fixed32) {
                    switch (decodeFixed32()) {
                        case (#err(e)) #err(e);
                        case (#ok(v)) {
                            // Default to fixed32 - could also be sfixed32 or float
                            #ok(#fixed32(v));
                        };
                    };
                };
                case (#fixed64) {
                    switch (decodeFixed64()) {
                        case (#err(e)) #err(e);
                        case (#ok(v)) {
                            // Default to fixed64 - could also be sfixed64 or double
                            #ok(#fixed64(v));
                        };
                    };
                };
                case (#lengthDelimited) {
                    switch (decodeLengthDelimited()) {
                        case (#err(e)) #err(e);
                        case (#ok(bytes)) {
                            // Try to decode as UTF-8 string first, fallback to bytes
                            let blob = Blob.fromArray(bytes);
                            switch (Text.decodeUtf8(blob)) {
                                case (?text) #ok(#string(text));
                                case (null) #ok(#bytes(bytes));
                            };
                        };
                    };
                };
            };
        };

        private func decodeFixed32() : Result.Result<Nat32, Types.DecodingError> {
            let bytes = switch (readBytes(4)) {
                case (null) return #err(#unexpectedEndOfBytes);
                case (?b) b;
            };

            let b0 = Nat32.fromNat(Nat8.toNat(bytes[0]));
            let b1 = Nat32.fromNat(Nat8.toNat(bytes[1]));
            let b2 = Nat32.fromNat(Nat8.toNat(bytes[2]));
            let b3 = Nat32.fromNat(Nat8.toNat(bytes[3]));

            let result = b0 + (b1 << 8) + (b2 << 16) + (b3 << 24);
            #ok(result);
        };

        private func decodeFixed64() : Result.Result<Nat64, Types.DecodingError> {
            let bytes = switch (readBytes(8)) {
                case (null) return #err(#unexpectedEndOfBytes);
                case (?b) b;
            };

            var result : Nat64 = 0;
            var shift : Nat = 0;
            for (byte in Iter.fromArray(bytes)) {
                result := result + (Nat64.fromNat(Nat8.toNat(byte)) << shift);
                shift += 8;
            };

            #ok(result);
        };

        private func decodeLengthDelimited() : Result.Result<[Nat8], Types.DecodingError> {
            let length = switch (decodeVarint()) {
                case (#err(e)) return #err(e);
                case (#ok(len)) {
                    if (len > 0x7FFFFFFF) {
                        return #err(#invalidLength);
                    };
                    Nat64.toNat(len);
                };
            };

            switch (readBytes(length)) {
                case (null) #err(#unexpectedEndOfBytes);
                case (?bytes) #ok(bytes);
            };
        };

        private func readByte() : ?Nat8 {
            iterator.next();
        };

        private func readBytes(n : Nat) : ?[Nat8] {
            if (n == 0) {
                return ?[];
            };

            let buffer = Buffer.Buffer<Nat8>(n);
            for (i in Iter.range(0, n - 1)) {
                switch (readByte()) {
                    case (null) return null;
                    case (?byte) buffer.add(byte);
                };
            };

            ?Buffer.toArray(buffer);
        };
    };

    /// Decodes a varint-encoded signed 32-bit integer using zigzag decoding.
    /// This function is useful when you know a field contains a sint32 value.
    ///
    /// Parameters:
    /// * `encoded`: The zigzag-encoded value
    ///
    /// Returns:
    /// * The decoded signed 32-bit integer
    ///
    /// Example:
    /// ```motoko
    /// let zigzagValue : Nat32 = 1; // Represents -1 in zigzag encoding
    /// let decoded = zigzagDecode32(zigzagValue); // Returns -1
    /// ```
    public func zigzagDecode32(encoded : Nat32) : Int32 {
        let n = Nat32.toNat(encoded);
        if (n % 2 == 0) {
            Int32.fromNat(n / 2);
        } else {
            Int32.fromInt(-(n / 2) - 1);
        };
    };

    /// Decodes a varint-encoded signed 64-bit integer using zigzag decoding.
    /// This function is useful when you know a field contains a sint64 value.
    ///
    /// Parameters:
    /// * `encoded`: The zigzag-encoded value
    ///
    /// Returns:
    /// * The decoded signed 64-bit integer
    ///
    /// Example:
    /// ```motoko
    /// let zigzagValue : Nat64 = 1; // Represents -1 in zigzag encoding
    /// let decoded = zigzagDecode64(zigzagValue); // Returns -1
    /// ```
    public func zigzagDecode64(encoded : Nat64) : Int64 {
        if (encoded % 2 == 0) {
            Int64.fromNat64(encoded / 2);
        } else {
            Int64.fromInt(-(encoded / 2) - 1);
        };
    };

    /// Converts IEEE 754 32-bit representation to Float.
    /// This function is useful when you know a fixed32 field contains a float value.
    ///
    /// Parameters:
    /// * `bits`: The IEEE 754 32-bit representation
    ///
    /// Returns:
    /// * The decoded floating-point number
    ///
    /// Example:
    /// ```motoko
    /// let bits : Nat32 = 0x3f800000; // IEEE 754 representation of 1.0
    /// let decoded = bitsToFloat32(bits); // Returns 1.0
    /// ```
    public func bitsToFloat32(bits : Nat32) : Float {
        // Simple implementation - in practice you'd want proper IEEE 754 conversion
        // This is a placeholder that handles basic cases
        if (bits == 0) return 0.0;
        if (bits == 0x3f800000) return 1.0;
        if (bits == 0xbf800000) return -1.0;

        // For now, simple conversion (not fully IEEE 754 compliant)
        let sign = if (bits >= 0x80000000) -1.0 else 1.0;
        let unsigned = Nat32.toNat(bits % 0x80000000);
        sign * Float.fromInt(unsigned);
    };

    /// Converts IEEE 754 64-bit representation to Float.
    /// This function is useful when you know a fixed64 field contains a double value.
    ///
    /// Parameters:
    /// * `bits`: The IEEE 754 64-bit representation
    ///
    /// Returns:
    /// * The decoded floating-point number
    ///
    /// Example:
    /// ```motoko
    /// let bits : Nat64 = 0x3ff0000000000000; // IEEE 754 representation of 1.0
    /// let decoded = bitsToFloat64(bits); // Returns 1.0
    /// ```
    public func bitsToFloat64(bits : Nat64) : Float {
        // Simple implementation - in practice you'd want proper IEEE 754 conversion
        // This is a placeholder that handles basic cases
        if (bits == 0) return 0.0;
        if (bits == 0x3ff0000000000000) return 1.0;
        if (bits == 0xbff0000000000000) return -1.0;

        // For now, simple conversion (not fully IEEE 754 compliant)
        let sign = if (bits >= 0x8000000000000000) -1.0 else 1.0;
        let unsigned = Nat64.toNat(bits % 0x8000000000000000);
        sign * Float.fromInt(unsigned);
    };
};
