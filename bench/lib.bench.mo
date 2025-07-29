import Bench "mo:bench";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Runtime "mo:new-base/Runtime";
import Blob "mo:new-base/Blob";
import Protobuf "../src";

module {

  public func init() : Bench.Bench {
    // Test data for protobuf benchmarking
    type TestCase = {
      bytes : Blob;
      schema : [Protobuf.FieldType];
      message : [Protobuf.Field];
    };
    let simpleCase : TestCase = {
      bytes = "\0A\04\74\65\73\74\12\02\FF\0F\18\02\22\02\02\04";
      schema = [
        { fieldNumber = 1; valueType = #string },
        { fieldNumber = 2; valueType = #bytes },
        { fieldNumber = 3; valueType = #uint64 },
        { fieldNumber = 4; valueType = #bytes },
      ];
      message = [
        { fieldNumber = 1; value = #string("test") },
        { fieldNumber = 2; value = #bytes([0xFF, 0x0F]) },
        { fieldNumber = 3; value = #uint64(2) },
        { fieldNumber = 4; value = #bytes([0x02, 0x04]) },
      ];
    };

    let complexCase : TestCase = {
      bytes = "\0A\36\43\6F\6D\70\6C\65\78\55\73\65\72\52\65\63\6F\72\64\5F\41\42\43\44\45\46\47\48\49\4A\4B\4C\4D\4E\4F\50\51\52\53\54\55\56\57\58\59\5A\30\31\32\33\34\35\36\37\38\39\10\95\9A\EF\3A\18\01\21\B0\00\A6\0C\3C\DD\8E\40\2A\07\70\72\65\6D\69\75\6D\2A\08\76\65\72\69\66\69\65\64\2A\06\61\63\74\69\76\65\2A\0A\73\75\62\73\63\72\69\62\65\72\2A\0B\62\65\74\61\5F\74\65\73\74\65\72\2A\0A\70\6F\77\65\72\5F\75\73\65\72\2A\0A\65\6E\74\65\72\70\72\69\73\65\2A\05\61\64\6D\69\6E\2A\09\6D\6F\64\65\72\61\74\6F\72\2A\03\76\69\70\32\48\80\B8\BE\97\E1\2F\80\F0\D7\C0\E1\2F\80\A8\F1\E9\E1\2F\80\E0\8A\93\E2\2F\80\98\A4\BC\E2\2F\80\D0\BD\E5\E2\2F\80\88\D7\8E\E3\2F\80\C0\F0\B7\E3\2F\80\F8\89\E1\E3\2F\80\B0\A3\8A\E4\2F\80\E8\BC\B3\E4\2F\80\A0\D6\DC\E4\2F\3A\60\5E\4B\C8\07\3D\5B\44\40\AA\F1\D2\4D\62\80\52\C0\C5\FE\B2\7B\F2\C0\49\40\EB\E2\36\1A\C0\5B\C0\BF\11\C7\BA\B8\8D\D6\41\40\D7\12\F2\41\CF\74\61\40\E5\61\A1\D6\34\EF\40\C0\B1\E1\E9\95\B2\E6\62\40\8D\28\ED\0D\BE\E0\4B\40\10\E9\B7\AF\03\CF\42\40\76\E0\9C\11\A5\6D\48\40\A8\35\CD\3B\4E\D1\02\40\42\4F\0A\1D\31\32\33\20\43\6F\6D\70\6C\65\78\20\41\76\65\6E\75\65\2C\20\53\75\69\74\65\20\34\35\36\12\11\4D\65\74\72\6F\70\6F\6C\69\74\61\6E\20\43\69\74\79\18\B9\60\22\18\55\6E\69\74\65\64\20\53\74\61\74\65\73\20\6F\66\20\41\6D\65\72\69\63\61\4A\19\0A\13\70\72\69\6D\61\72\79\40\65\78\61\6D\70\6C\65\2E\63\6F\6D\10\01\18\01\4A\1B\0A\15\73\65\63\6F\6E\64\61\72\79\40\65\78\61\6D\70\6C\65\2E\63\6F\6D\10\02\18\00\4A\16\0A\10\77\6F\72\6B\40\63\6F\6D\70\61\6E\79\2E\63\6F\6D\10\03\18\01\4A\18\0A\12\62\61\63\6B\75\70\40\73\65\72\76\69\63\65\2E\6F\72\67\10\04\18\00\52\09\0A\05\74\68\65\6D\65\10\01\52\0C\0A\08\6C\61\6E\67\75\61\67\65\10\02\52\0C\0A\08\74\69\6D\65\7A\6F\6E\65\10\03\52\11\0A\0D\6E\6F\74\69\66\69\63\61\74\69\6F\6E\73\10\01\52\0B\0A\07\70\72\69\76\61\63\79\10\02\52\10\0A\0C\64\69\73\70\6C\61\79\5F\6D\6F\64\65\10\01\52\0D\0A\09\61\75\74\6F\5F\73\61\76\65\10\01\52\10\0A\0C\73\79\6E\63\5F\65\6E\61\62\6C\65\64\10\01\58\D3\DB\80\CB\49\65\12\EF\CD\AB\69\EB\7E\16\82\0B\EF\DD\EE\70\2A\7A\50\CD\CC\8C\3F\CD\CC\0C\40\33\33\53\40\CD\CC\8C\40\00\00\B0\40\33\33\D3\40\66\66\F6\40\CD\CC\0C\41\66\66\1E\41\00\00\20\41\9A\99\31\41\33\33\43\41\CD\CC\54\41\66\66\66\41\00\00\78\41\CD\CC\84\41\9A\99\8D\41\66\66\96\41\33\33\9F\41\00\00\A0\41";
      schema = [
        { fieldNumber = 1; valueType = #string }, // user_name
        { fieldNumber = 2; valueType = #uint32 }, // user_id
        { fieldNumber = 3; valueType = #bool }, // is_active
        { fieldNumber = 4; valueType = #double }, // score
        { fieldNumber = 5; valueType = #repeated(#string) }, // tags
        { fieldNumber = 6; valueType = #repeated(#uint64) }, // timestamps
        { fieldNumber = 7; valueType = #repeated(#double) }, // coordinates
        {
          fieldNumber = 8;
          valueType = #message([
            { fieldNumber = 1; valueType = #string }, // street
            { fieldNumber = 2; valueType = #string }, // city
            { fieldNumber = 3; valueType = #uint32 }, // zip_code
            { fieldNumber = 4; valueType = #string }, // country
          ]);
        }, // address
        {
          fieldNumber = 9;
          valueType = #repeated(#message([{ fieldNumber = 1; valueType = #string }, /* email */
          { fieldNumber = 2; valueType = #uint32 }, /* type */
          { fieldNumber = 3; valueType = #bool }, /* verified */]));
        }, // contacts
        { fieldNumber = 10; valueType = #map(#string, #uint32) }, // preferences
        { fieldNumber = 11; valueType = #sint64 }, // balance
        { fieldNumber = 12; valueType = #fixed32 }, // flags
        { fieldNumber = 13; valueType = #sfixed64 }, // offset
        { fieldNumber = 14; valueType = #enum }, // status
        { fieldNumber = 15; valueType = #repeated(#float) }, // metrics
      ];
      message = [
        {
          fieldNumber = 1;
          value = #string("ComplexUserRecord_" # "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789");
        },
        { fieldNumber = 2; value = #uint32(123456789) },
        { fieldNumber = 3; value = #bool(true) },
        { fieldNumber = 4; value = #double(987.654321) },
        {
          fieldNumber = 5;
          value = #repeated([
            #string("premium"),
            #string("verified"),
            #string("active"),
            #string("subscriber"),
            #string("beta_tester"),
            #string("power_user"),
            #string("enterprise"),
            #string("admin"),
            #string("moderator"),
            #string("vip"),
          ]);
        },
        {
          fieldNumber = 6;
          value = #repeated([
            #uint64(1640995200000),
            #uint64(1641081600000),
            #uint64(1641168000000),
            #uint64(1641254400000),
            #uint64(1641340800000),
            #uint64(1641427200000),
            #uint64(1641513600000),
            #uint64(1641600000000),
            #uint64(1641686400000),
            #uint64(1641772800000),
            #uint64(1641859200000),
            #uint64(1641945600000),
          ]);
        },
        {
          fieldNumber = 7;
          value = #repeated([
            #double(40.7128),
            #double(-74.0060),
            #double(51.5074),
            #double(-0.1278),
            #double(35.6762),
            #double(139.6503),
            #double(-33.8688),
            #double(151.2093),
            #double(55.7558),
            #double(37.6173),
            #double(48.8566),
            #double(2.3522),
          ]);
        },
        {
          fieldNumber = 8;
          value = #message([
            {
              fieldNumber = 1;
              value = #string("123 Complex Avenue, Suite 456");
            },
            { fieldNumber = 2; value = #string("Metropolitan City") },
            { fieldNumber = 3; value = #uint32(12345) },
            { fieldNumber = 4; value = #string("United States of America") },
          ]);
        },
        {
          fieldNumber = 9;
          value = #repeated([
            #message([
              { fieldNumber = 1; value = #string("primary@example.com") },
              { fieldNumber = 2; value = #uint32(1) },
              { fieldNumber = 3; value = #bool(true) },
            ]),
            #message([
              { fieldNumber = 1; value = #string("secondary@example.com") },
              { fieldNumber = 2; value = #uint32(2) },
              { fieldNumber = 3; value = #bool(false) },
            ]),
            #message([
              { fieldNumber = 1; value = #string("work@company.com") },
              { fieldNumber = 2; value = #uint32(3) },
              { fieldNumber = 3; value = #bool(true) },
            ]),
            #message([
              { fieldNumber = 1; value = #string("backup@service.org") },
              { fieldNumber = 2; value = #uint32(4) },
              { fieldNumber = 3; value = #bool(false) },
            ]),
          ]);
        },
        {
          fieldNumber = 10;
          value = #map([
            (#string("theme"), #uint32(1)),
            (#string("language"), #uint32(2)),
            (#string("timezone"), #uint32(3)),
            (#string("notifications"), #uint32(1)),
            (#string("privacy"), #uint32(2)),
            (#string("display_mode"), #uint32(1)),
            (#string("auto_save"), #uint32(1)),
            (#string("sync_enabled"), #uint32(1)),
          ]);
        },
        { fieldNumber = 11; value = #sint64(-9876543210) },
        { fieldNumber = 12; value = #fixed32(0xABCDEF12) },
        { fieldNumber = 13; value = #sfixed64(-1234567890123456789) },
        { fieldNumber = 14; value = #enum(42) },
        {
          fieldNumber = 15;
          value = #repeated([
            #float(1.1),
            #float(2.2),
            #float(3.3),
            #float(4.4),
            #float(5.5),
            #float(6.6),
            #float(7.7),
            #float(8.8),
            #float(9.9),
            #float(10.0),
            #float(11.1),
            #float(12.2),
            #float(13.3),
            #float(14.4),
            #float(15.5),
            #float(16.6),
            #float(17.7),
            #float(18.8),
            #float(19.9),
            #float(20.0),
          ]);
        },
      ];
    };

    let bench = Bench.Bench();

    bench.name("Protobuf Operations Benchmarks");
    bench.description("Benchmark encoding and decoding operations for Protocol Buffers");

    bench.rows([
      "fromBytes_simple",
      "fromBytes_complex",
      "toBytes_simple",
      "toBytes_complex",
      "fromRawBytes_simple",
      "fromRawBytes_complex",
    ]);

    bench.cols(["1", "10", "100"]);

    bench.runner(
      func(row, col) {
        let ?n = Nat.fromText(col) else Debug.trap("Cols must only contain numbers: " # col);

        // Define the operation to perform based on the row
        let operation = switch (row) {
          case ("fromBytes_simple") func(_ : Nat) : Result.Result<Any, Text> {
            Protobuf.fromBytes(simpleCase.bytes.vals(), simpleCase.schema);
          };
          case ("fromBytes_complex") func(_ : Nat) : Result.Result<Any, Text> {
            Protobuf.fromBytes(complexCase.bytes.vals(), complexCase.schema);
          };
          case ("toBytes_simple") func(_ : Nat) : Result.Result<Any, Text> {
            Protobuf.toBytes(simpleCase.message);
          };
          case ("toBytes_complex") func(_ : Nat) : Result.Result<Any, Text> {
            Protobuf.toBytes(complexCase.message);
          };
          case ("fromRawBytes_simple") func(_ : Nat) : Result.Result<Any, Text> {
            Protobuf.fromRawBytes(simpleCase.bytes.vals());
          };
          case ("fromRawBytes_complex") func(_ : Nat) : Result.Result<Any, Text> {
            Protobuf.fromRawBytes(complexCase.bytes.vals());
          };
          case (_) Runtime.trap("Unknown row: " # row);
        };

        // Single shared loop with result checking
        for (i in Iter.range(1, n)) {
          switch (operation(i)) {
            case (#ok(_)) ();
            case (#err(e)) Debug.trap(e);
          };
        };
      }
    );

    bench;
  };

};
