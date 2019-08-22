# CommonCoder

Common Swift Encoder/Decoder

## CSV Coders

Encoder and decoder for CSV file format as per [RFC 4180](https://tools.ietf.org/html/rfc4180)

A decoding example,

```swift
import LNTCSVCoder

struct SomeStruct: Equatable, Codable {
  var a: Int, b: Double?, c: String
}

let decoder = CSVDecoder() // default options

let string = """
a,b,c
4,,test
6,9.9,ss
"""

let values = try decoder.decode(SomeStruct.self, from: string)
/* 
values = [
  SomeStruct(a: 4, b: nil, c: "test"), // first row
  SomeStruct(a: 6, b: 9.9, c: "ss") // second row
]
 */
```

An encoding example,

```swift
import LNTCSVCoder

struct SomeStruct: Equatable, Codable {
  var a: Int, b: Double?, c: String
}
struct OtherStruct: Equatable, Codable {
  var a: Float?, b: SomeStruct 
}

let values = [
  OtherStruct(a: 5.5, b: .init(a: 4.4, b: 1, c: "abc")),
  OtherStruct(a: nil, b: .init(a: .infinity, b: nil, c: ""))
]

let encoder = CSVEncoder() // default options
let string = encoder.encode(values)
/*
string = """ 
  float,some.a,some.b,some.c
  5.5,4,inf,abc
  ,-3,,
  """
*/
```

Note that both times the Swift data is a sequence of values. This is due to tabular nature of CSV.

### Header structure

CSV coders require the CSV string to contains header.
* Header field for elements in `KeyedContainer` is the `stringValue` of the `key` used to encode/decode data.
* Header field for elements in `UnkeyedContainer` is the offset (converted to `String`) from the beginning of the container `0, 1, 2, ...`.
* Nested containers will use `subheaderSeparator` (defaulted to `.`) to separated between subfields at each level. Thus every subfield must not contain `subheaderSeparator`.
* Super encoder uses `super` as a subfield if none is provided.

As such, the following structure

```
class A: Codable {
  var a: ..., b: ..., c: ...
}
class B: A {
  var a: ..., b: ..., c: ... 
}
```

translates `B` into

```
- B -|------ A values -------
a,b,c,super.a,super.b,super.c
```

### CSVEncoder Functions

```
public init(separator: Character = ",", subheaderSeparator: Character = ".", options: CSVEncodingOptions = [], userInfo: [CodingUserInfoKey: Any] = [:])
```

* `separator`: Separator used to break eack column. Also applies to header.
* `subheaderSeparator`: Separator used to separate each subheader if there are nested containers.
* `options`: 
  * `omitHeader`: Don't print header line.
  * `alwaysQuots`: Escape every data by inserting quotes `""` (including numerical values).
  * `useNullAsNil`: Uses unescaped string `null` to represent `nil` (default is unescaped empty string).
* `userInfo`: Custom user info to pass into encoding process.

Note that everything EXCEPT `separator` and `subheaderSeparator` can be changed after the initialization via appropriate accessor.

```
public func encode<S>(_ values: S) throws -> String where S: Sequence, S.Element: Encodable
```

* Encode `values` into CSV string data.

* `values`: `Sequence` of values to encode.

* return value: `String` of the encoded CSV data.
* throws `EncodingError` with the following descriptions:
  * _Key does not match any header fields_: if a new key is used after encoder encoded the first item (and finalized the header line).
  * _Duplicated field_: if the same field is encoded twice.

```
public func encode<S, Output>(_ values: S, into output: inout Output) throws where S: Sequence, S.Element: Encodable, Output: TextOutputStream
```

* Encode `values` and write the result into `output`.

* `values`: `Sequence` of values to encode.
* `output`: the destination of the encoded string.

* throws `EncodingError` with the following descriptions:
  * _Key does not match any header fields_: if a new key is used after encoder encoded the first item (and finalized the header line).
  * _Duplicated field_: if the same field is encoded twice.

### CSVDecoder Functions

```
public init(separator: Character = ",", subheaderSeparator: Character = ".", options: CSVDecodingOptions = [], userInfo: [CodingUserInfoKey: Any] = [:])
```

* `separator`: Separator used to break eack column. Also applies to header.
* `subheaderSeparator`: Separator used to separate each subheader if there are nested containers.
* `options`: 
  * `treatEmptyStringAsValue`: treats unescaped empty string as empty string (default is to treat it as `nil`).
  * `treatNullAsNil`: treats unescaped `null` as `nil`.
* `userInfo`: Custom user info to pass into encoding process .

Note that everything EXCEPT `separator` and `subheaderSeparator` can be changed after the initialization via appropriate accessor.

```
public func decode<S, T>(_ type: T.Type, from string: S) throws -> [T] where S: Sequence, S.Element == Character, T: Decodable
```

* Decode an array of type `T` from `string`

* `type`: type to the decoded data.
* `string`: CSV data to decode.

* `throws`
  * `DecodingError.dataCorrupted` _Expecting multi-field object_: if the decoder found unnested data (`a`), but is expecting a nested data (`a.a`, `a.b`, etc). 
  * `DecodingError.keyNotFound`: if the type tries to uses `key` not present in `string` for keyed container, or decode past the end for unkeyed container.
  * `DecodingError.typeMismatch` _Multi-field object found_: if the decoder found a nested data (`a.a`, `a.b`, etc), but is expecting unnested data (`a`). 
  * `DecodingError.valueNotFound`: found `nil` when expecting a non-nil value.
  * `DecodingError.typeMismatch` _Trying to decode \`Type\`_: the value can not be converted to `Type`.
