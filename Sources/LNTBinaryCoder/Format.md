# Format

This format consists of 2 parts: String map and Data storage. Each part is stored separately as shown below:

```
*--------------------------------------------------------*
| 0x00 | 0x00 | String count | String map | Data storage |
*--------------------------------------------------------*
```

String count, the number of strings in String map, is stored in the beginning using Variable-Sized Unsigned Integer (see below).

## Variable-Sized Unsigned Integer

This format extensively uses Variable-Sized Unsigned Integer (VSUI). The format is as follows, for each byte:

- The Most Significant Bit (MSB) is used as continuation bit. It is 1 if the next byte is part of this integer, and 0 otherwise.
- Other 7 bits is used for the actual value, in big-endian order.

For example, consider `[0x99, 0xf2, 0xe3, 0x17]`

1. This integer consists of `[0x99, 0xf2, 0xe3, 0x17]` as `0x17` is the first byte with clear MSB.
2. Stripping MSB from each bytes: `[0x19, 0x72, 0x63, 0x17]`.
3. Adding each byte together: `(0x19 << 21) + (0x72 << 14) + (0x63 << 7) + (0x17)`
4. The result from Step 3 is `0x33cb197`, or `54309271`.

So the value of this byte pattern is `54309271`.

**Note**

In theory, this format allows for integers of arbitrary size to be stored. In practive, the encoder and decoder generally use native integers to store and compute these values. As such, data encoded with 64-bit machine may not be decoded successfully on 32-bit machine.

## String Map

The String map is an array containing all strings found in the data storage (especially keys). Data storage refers to values in this array using (1-based) indices.

String map is stored as a sequence of utf-8 strings, separated by null terminator.

## Data Storage

The format of each container is described below. Some containers have end-point markers which is indicated by parenthesis. These markers will be used should there be enough space, and will be ignored otherwise.

### Tags, Headers, and Payload

Every container consists of two portions; header, and payload.
- Header contains the metadata to the data block (including Tag).
  - Tag is part of the header. It is the first byte used to determine the type of the storage.
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

### Single-Value Container

This section includes all supported single-value container. The headers of these containers consists of only the tag, the rest are payloads.

Note:
This is different from `SingleValueDecodingContainer` and `SingleValueEncodingContainer`, which is transparent to the format.  

#### Nil

`nil` is stored as a single (optional) tag `0x01`:

```
*--------*
| (0x01) |
*--------*
```

#### Fixed Width Types

Types in this category include `FixedWidthInteger`s. It is stored as a tag `0x02`, followed by the payload.

```
*------*------*
| 0x02 | Data |
*------*------*
```

Payloads are stored in little-endian order, and is of the same size as the object itself, e.g. 4 bytes for `Int32`.

#### `Int`, `UInt`, `Float`, `Double`, and `Bool`

Types in this category delegates the encoding to another types.

- `Int` is encoded as `Int64`.
- `UInt` is encoded as `UInt64`.
- `Float` is encoded as `UInt32` (using bit pattern).
- `Double` is encoded as `UInt64` (using bit pattern).
- `Bool` is encoded as `UInt8`. It is `false` if the value is `0`, and is `true` otherwise.

#### String

`String` is stored inside String map, and be refered to from Data storage using (VSUI) index.

```
*------*-----*
| 0x03 | Key |
*------*-----*
```

### Keyed Container

Keyed container has a few representations with different size-performance tradeoff. Encoders may choose any valid representation.

#### Regular Case

This is valid for all containers containing at least one key. 

```
*-----------------------------------------------------*--------------------------------*
|                        Header                       |             Payload            |
*-----------------------------------------------------*--------------------------------*
| 0x10 | Size 1 | Key 1 | ... | Size n | Key n | 0x01 | Item 1 | Item 2 | ... | Item n |
*-----------------------------------------------------*--------------------------------*
```

Note that `Size n` is replaced with `0x01` to denote the last key.

#### Equisized Case

This is valid if all payloads have the same size.

```
*--------------------------------------------------*--------------------------------*
|                      Header                      |             Payload            |
*--------------------------------------------------*--------------------------------*
| 0x11 | Size | Key 1 | Key 2 | ... | Key n | 0x00 | Item 1 | Item 2 | ... | Item n |
*--------------------------------------------------*--------------------------------*
```

#### Uniform Case

This is valid if all payload have the same size and header.

```
*-----------------------------------------------------------*-----------------------------------------*
|                           Header                          |                 Payload                 |
*-----------------------------------------------------------*-----------------------------------------*
| 0x12 | Size | Header | Key 1 | Key 2 | ... | Key n | 0x00 | Payload 1 | Payload 2 | ... | Payload n |
*-----------------------------------------------------------*-----------------------------------------*
```

### Unkeyed Container

Unkeyed container has a few representations with different size-performance tradeoff. Encoders may choose any valid representation.

#### Regular Case

This is valid for all containers.

```
*----------------------------------------------*--------------------------------*
|                    Header                    |             Payload            |
*----------------------------------------------*--------------------------------*
| 0x20 | Size 1 | Size 2 | ... | Size n | 0x01 | Item 1 | Item 2 | ... | Item n |
*----------------------------------------------*--------------------------------*
```

#### Equisized Case

This is valid if all payloads have the same size.

```
*-------------*-----------------------------------------*
|    Header   |                 Payload                 |
*-------------*-----------------------------------------*
| 0x21 | Size | Item 1 | Item 2 | ... | Item n | (0x00) |
*-------------*-----------------------------------------*
```

#### Uniform Case

This is valid if all payloads have the same size and header.

```
*------------------------------*-----------------------------------------*
|            Header            |                 Payload                 |
*------------------------------*-----------------------------------------*
| 0x22 | Size | Header | Count | Payload 1 | Payload 2 | ... | Payload n |
*------------------------------*-----------------------------------------*
```

### Design Note

#### Padding

This format is designed specifically to allow padding, to add byte at the end of data. Where it would be ambiguous between data and gibberish, it uses an *endpoint marker* which will generally be an invalid value to appear in the middle.

For keyed and unkeyed containers, this also allows payloads with different sizes to be padded so that the sizes are equal, making the container eligible for equisized form. 

#### Values of Tags

The *tags* of objects can not be `0x00`. Some containers used `0x00` as endpoint markers where tags would be if there are more items.

We should also reserve some tags (`0x80` - `0xff`) for when the tag space is filled up. At which point we can still use them as a head for multibyte tags.

#### Size of Item

It is possible to avoid using object of size 1 altogether. `nil` object can be encoded as empty byte, and all other objects requires at least 2 bytes (1 for tag, 1 for data). As such, some containers uses `0x01` as an endpoint marker as its location overlapped where `Size` would be. The only reason this would be problematic is if we add another data-less type, another `nil`-list type.

One alternative would be to have `nil` strictly be 1-byte, and use `0x00` as the endpoint, but having `nil` be 0 byte saves more space without much sacrifice in performance.

#### Uniqueness of VSUI

A VSUI byte pattern uniquely determines the integer value. The converse is not true.
For example, following byte patterns matches `0x42`:

- `[0x42]`
- `[0x80, 0x42]`
- `[0x80, 0x80, 0x42]`
- `[0x80, 0x80, 0x80, 0x42]`

and so on. This is intentional as it allows the encoder to make a trade-off between compression rate and encoding performance. An encoder may not know value of each integer at the time of encoding and put a fixed-size placeholder for editing later. Achieving higher compression rate may require the encoder to run another pass to optimize those placeholders.

#### Non-overlapping Rule

The data storage employs non-overlapping rule. As such the maximum size of an object can be calculated using the position of the next object (and of the current object). The top-level object can be any valid object.
