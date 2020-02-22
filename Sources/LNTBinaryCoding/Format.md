# Variable-Sized Unsigned Integer

We extensively uses Variable-Sized Unsigned Integer (VSUI). The format is as follows, for each byte:

- The Most Significant Bit (MSB) is used as continuation bit. It is 1 if the next byte is part of this integer, and 0 otherwise.
- Other 7 bits is used for the actual value, in big-endian order.

For example, consider `[0x99, 0xf2, 0xe3, 0x17]`

1. This integer consists of `[0x99, 0xf2, 0xe3, 0x17]` as `0x17` is the first byte with clear MSB.
2. Stripping MSB from each bytes: `[0x19, 0x72, 0x63, 0x17]`.
3. Adding each byte together: `(0x19 << 21) + (0x72 << 14) + (0x63 << 7) + (0x17)`
4. The result from Step 3 is `0x33cb197`, or `54309271`.

So the value of this byte pattern is `54309271`.

**Note**

In theory, VSUI permits integer of any size. In practive, the encoder and decoder use native `Int` to calculate these values. As such, data encoded with 64-bit machine may not be decoded successfully on 32-bit machine.

# File Format

Binary file format consists of 3 parts: Version Number, String map, and Data storage. Each part is stored separately as shown below:

```
*--------------------------------------------*
| Version Number | String Map | Data Storage |
*--------------------------------------------*
```

# Version Number

The first two bytes are version number. Currently the value is `0x00 0x00`

```
*-------------*
| 0x00 | 0x00 |
*-------------*
```

# String Map

String map is an array containing all strings found in the data storage (especially keys). Data storage refers to values in string map using 1-based indices.

String map starts with a VSUI number indicating the total number of strings, followed by list of null-terminated strings.

```
*-------------------------------------------------*
| N (VSUI) | String 1 | String 2 | ... | String N | 
*-------------------------------------------------*
```

# Data Storage

Data storage contains a single object in form of a container. This section describes all valid containers.

## Tags, Headers, and Payload

Every container consists of two portions; header, and payload.
- Header contains the metadata to the data block (including Tag).
  - Tag is the first byte of the header. It is used to determine the type of the container.
- Payload contains the data that is being stored.

For all diagrams, we use the following legend:

- Item: The payload.
- Payload: The payload with the header stripped out.
- Size (VSUI): The size of the item.
- Key (VSUI): The index to the String map. Mostly for containing keys in keyed containers. 

For multi-item containers:
- Count (VSUI): The number of item.
- Tag: The tag shared among items.
- Header: The header shared among items.

## Single-Value Container

This section includes all supported single-value container. The headers of these containers consists of only tags, the rest are payloads.

Note:
This is different from `SingleValueDecodingContainer` and `SingleValueEncodingContainer`, which are transparent to the format.  

### Nil

`nil` is stored as an empty block. If the block is not empty, the first byte will be the tag, `0x01`. 

```
*--------*
| (0x01) |
*--------*
```

### Signed Integer Types

Types in this category include `Int`, `Int8`, `Int16`, `Int32`, `Int64`. It is stored as a tag followed by the payload in little endian byte order.

If the payload is shorter than the expected type (storing `Int64` on a three-byte space), the remaining byte follows the sign bit of the last byte. 
If the payload is longer than the expected type (storing `Int64` on a five-byte space), the unused bytes, up to 16 bytes including the payload, are set to follow the signs of the last byte.  

```
*--------------------------*
| 0x02 | Data | (sign) ... |
*--------------------------*
```

### Unsigned Integer Types

Types in this category include `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64`. It is stored as a tag followed by the payload in little endian byte order.

If the payload is shorter than the expected type (storing `UInt64` on a three-byte space), the remaining bytes are treated as zero. 
If the payload is longer than the expected type (storing `UInt64` on a five-byte space), the unused bytes, up to 16 bytes including the payload, are set to zero.  

```
*--------------------------*
| 0x03 | Data | (0x00) ... |
*--------------------------*
```

### Delegating Types

Types in this category delegates the encoding to another types.

- `Float` is encoded as `UInt32` (using bit pattern).
- `Double` is encoded as `UInt64` (using bit pattern).
- `Bool` is encoded as `UInt8`. It is `false` if the value is `0`, and is `true` otherwise.

### String

`String` is stored inside String map, and be refered to from Data storage using (VSUI) index.

```
*------*-------*
| 0x04 | Index |
*------*-------*
```

## String-Based Keyed Container

String-based keyed container has a few representations with different size-performance tradeoff. Encoders may choose any valid representation.

### Regular Case

This is valid for all containers.

```
*-----------------------------------------------------*--------------------------------*
|                        Header                       |             Payload            |
*-----------------------------------------------------*--------------------------------*
| 0x10 | Size 1 | Key 1 | ... | Size n | Key n | 0x01 | Item 1 | Item 2 | ... | Item n |
*-----------------------------------------------------*--------------------------------*
```

### Equisized Case

This is valid if all items have the same size.

```
*--------------------------------------------------*--------------------------------*
|                      Header                      |             Payload            |
*--------------------------------------------------*--------------------------------*
| 0x11 | Size | Key 1 | Key 2 | ... | Key n | 0x00 | Item 1 | Item 2 | ... | Item n |
*--------------------------------------------------*--------------------------------*
```

### Uniform Case

This is valid if all items have the same size and header.

```
*-----------------------------------------------------------*-----------------------------------------*
|                           Header                          |                 Payload                 |
*-----------------------------------------------------------*-----------------------------------------*
| 0x12 | Size | Key 1 | Key 2 | ... | Key n | 0x00 | Header | Payload 1 | Payload 2 | ... | Payload n |
*-----------------------------------------------------------*-----------------------------------------*
```

## Int-Based Keyed Container

This format does not support `Int`-based keyed container. Keys are converted to `String` and the container is encoded as string-based keyed container.

## Unkeyed Container

Unkeyed container has a few representations with different size-performance tradeoff. Encoders may choose any valid representation.

### Regular Case

This is valid for all containers.

```
*----------------------------------------------*--------------------------------*
|                    Header                    |             Payload            |
*----------------------------------------------*--------------------------------*
| 0x20 | Size 1 | Size 2 | ... | Size n | 0x01 | Item 1 | Item 2 | ... | Item n |
*----------------------------------------------*--------------------------------*
```

### Equisized Case

This is valid if all items have the same size, and the container contains at least one item. If there are more space than needed, last item will be followed by `0x00`.

```
*-------------*-----------------------------------------*
|    Header   |                 Payload                 |
*-------------*-----------------------------------------*
| 0x21 | Size | Item 1 | Item 2 | ... | Item n | (0x00) |
*-------------*-----------------------------------------*
```

### Uniform Case

This is valid if all items have the same size and header.

```
*------------------------------*-----------------------------------------*
|            Header            |                 Payload                 |
*------------------------------*-----------------------------------------*
| 0x22 | Size | Count | Header | Payload 1 | Payload 2 | ... | Payload n |
*------------------------------*-----------------------------------------*
```

Note that `Size` referes to the size of the item (with header attached) not the size of the payload.

# Design Note

## Padding

This format is designed specifically to allow padding at the end of the data. It uses an *endpoint marker* anywhere the boundary between data and the padding is ambiguous.

For keyed and unkeyed containers, this also allows payloads with different sizes to be padded to make the containers eligible for equisized form.

## Values of Tags

The *tags* of objects can not be `0x00`. Some containers used `0x00` as endpoint markers where tags would be should there be more items.

We should also reserve some tags (`0x80` - `0xff`) for when the tag space is filled up. At which point we can still use them as a head for multi-byte tags.

## Size of Item

It is possible to avoid using object of size 1 altogether. `nil` object can be encoded as empty block, and all other objects requires at least 2 bytes (1 for tag, 1 for data). As such, some containers uses `0x01` as an endpoint marker as its location overlapped where `Size` would be. One reason this would be problematic is if we add another data-less type.

One alternative would be to have `nil` use exactly 1 byte, and use `0x00` as the endpoint, but having `nil` be 0 byte saves more space without much sacrifice in performance.

## Uniqueness of VSUI

A VSUI byte pattern uniquely determines the integer value. The converse is not true.
For example, following byte patterns matches `0x42`:

- `[0x42]`
- `[0x80, 0x42]`
- `[0x80, 0x80, 0x42]`
- `[0x80, 0x80, 0x80, 0x42]`

and so on. This is intentional as it allows the encoder to make a trade-off between compression rate and encoding performance. An encoder may not know value of each integer at the time of encoding and put a fixed-size placeholder for editing later. Achieving higher compression rate may require the encoder to run another pass to optimize those placeholders.

## Non-overlapping Rule

The data storage employs non-overlapping rule. As such, the size of an object can be calculated using the position of the next object (and of the current object).