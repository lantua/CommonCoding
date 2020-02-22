# CommonCoding

Common Swift Encoder/Decoder

## Binary Codings

Encoder and decoder for binary file format.
For format specification, see [Format](Sources/LNTBinaryCoding/Format.md)

**Note**: We have not reached 1.0 yet, and so the format for these coders may change in incompatible ways over time.

## CSV Codings

Encoder and decoder for CSV file format as per [RFC 4180](https://tools.ietf.org/html/rfc4180).
For API information, see [CSV README](Sources/LNTCSVCoding/README.md).

A decoding example,

```swift
import LNTCSVCoding

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
import LNTCSVCoding

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
