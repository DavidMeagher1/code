# Forth-like language
## Table of contents
___
1. [Opcode specification](#opcode-specification)
   - [Extension bit](#1-extension-bit-e)
   - [Size bit](#2-size-bit-s)
   - [Id bits](#3-id-bits-6-bits-iiiiii)
   - [Extended Opcodes](#extended-opcodes)
   - [Example Opcodes](#example-opcodes)
   - [Opcode Families](#opcode-families)
     - [System / Traps](#system--traps)
     - [Control flow](#control-flow)
     - [Stack manipulation](#stack-manipulation)
     - [Arithmetic](#arithmetic)
     - [Bitwise](#bitwise)
     - [Memory access](#memory-access)
2. [Binary file specification](#binary-file-specification)
   - [File Structure](#file-structure)
   - [File Header](#file-header)
   - [Chunk Format](#chunk-format)
   - [Standard Chunk Types](#standard-chunk-types)
     - [CODE - Code Section](#code---code-section)
     - [COMP - Compression Metadata](#comp---compression-metadata)
     - [DEBG - Debug Information](#debg---debug-information)
   - [Example File Layout](#example-file-layout)
   - [Extensibility](#extensibility)
3. [System Architecture](#system-architecture)
   - [Memory Model](#memory-model)
   - [Physical Addressing](#physical-addressing)
4. [PNG Cartridge Format](#png-cartridge-format)
   - [Image Requirements](#image-requirements)
   - [Embedding Method](#embedding-method)
   - [Capacity](#capacity)
   - [Embedding Process](#embedding-process)
   - [Extraction Process](#extraction-process)
   - [Visual Impact](#visual-impact)
   - [Benefits](#benefits)
5. [Language specification](#language-specification)
   - [Comments](#comments)
   - [Literals](#literals)
     - [Integer literals](#integer-literals)
     - [Character literals](#character-literals)
     - [String literals](#string-literals)
   - [Labels](#labels)
     - [Label types](#label-types)
       - [Global labels](#global-labels)
       - [Local labels](#local-labels)
     - [Referencing labels](#referencing-labels)
       - [Scoping and resolution of references](#scoping-and-resolution-of-references)
   - [Padding](#padding)
     - [Absolute padding |](#absolute-padding-)
     - [Relative padding $](#relative-padding-)
___

## Opcode specification
standard opcodes are 8 bits and will be described going from most to least significant bits eg:
ESIIIIII

### 1. Extension bit `E`
the extension bit tells the VM to look at the next byte to extend the opcode to 16 bits (described more later)

### 2. Size bit `S`
the next bit, the "Size" bit determines the data type that the VM is working with and the options are described in this table

| Bit | Size   | Type |
|-----|--------|------|
| 0   | 8-bit  | byte |
| 1   | 16-bit | word |

### 3. Id bits (6 bits) `IIIIII`
these bits define what the specific opcode actually does and should be organized into families

For standard opcodes (E=0): 6 bits = 64 possible operations per size

For extended opcodes (E=1): 14 bits = 16,384 possible operations per size

See [Families](#opcode-families) for more specific info on how opcodes are organized

### Extended Opcodes
opcodes whose first byte has the extension bit set are then expected to have another byte whose bits contribute to the Id bits in the first byte

When E=0, the opcode format is:
```
E-S-IIIIII
``` 

when E=1, the complete opcode format is:
```
Byte 1: E-S-IIIIII 
Byte 2: IIIIIIII
```

### Example opcodes
**Standard 8-bit opcode:**
```
01010011 = 0x53
││└┴┴┴┴┴─ ID bits (19 = some operation)
│└─────── Size: 1 = 16-bit (word)
└──────── Extension: 0 = standard
```
**Extended 16-bit opcode:**
```
10110001 00101100 = 0xB12C
││└┴┴┴┴┴ └┴┴┴┴┴┴┴┴─ ID bits (14-bit: 110001 00101100)
│└────────────────── Size: 1 = 16-bit (word)
└─────────────────── Extension: 1 = extended opcode
```
### Opcode Families

**Special Opcode IDs - Size-Independent Operations**

For operations where data size is irrelevant, certain opcode IDs use the size bit to select between different operations rather than data types.

#### System / Traps

**ID 0x00:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x00 | 0 0 000000 | 0x00 | `INVALID` | Invalid opcode - VM crashes with error |
| E=0 S=1 ID=0x00 | 0 1 000000 | 0x40 | `NOP` | No operation - does nothing |

**ID 0x01:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x01 | 0 0 000001 | 0x01 | `HALT` | Stop VM execution |
| E=0 S=1 ID=0x01 | 0 1 000001 | 0x41 | `TRAP` | System call - trap number follows as immediate byte |

#### Control flow

**ID 0x02:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x02 | 0 0 000010 | 0x02 | `JMPS` | Jump short/relative (1-byte signed offset follows) |
| E=0 S=1 ID=0x02 | 0 1 000010 | 0x42 | `JMPL` | Jump long/absolute (2-byte address follows) |

**ID 0x03:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x03 | 0 0 000011 | 0x03 | `HOPS` | Hop short/relative (pops 1-byte signed offset) |
| E=0 S=1 ID=0x03 | 0 1 000011 | 0x43 | `HOPL` | Hop long/absolute (pops 2-byte address) |

**ID 0x04:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x04 | 0 0 000100 | 0x04 | `CALLS` | Call short/relative (pops 1-byte signed offset) |
| E=0 S=1 ID=0x04 | 0 1 000100 | 0x44 | `CALLL` | Call long/absolute (pops 2-byte address) |

**ID 0x05:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x05 | 0 0 000101 | 0x05 | `RETS` | Return short/relative (pops 1-byte signed offset) |
| E=0 S=1 ID=0x05 | 0 1 000101 | 0x45 | `RETL` | Return long/absolute (pops 2-byte address) |

**ID 0x06:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x06 | 0 0 000110 | 0x06 | `JNZS` | Jump short if not zero (pops condition, pops 1-byte offset) |
| E=0 S=1 ID=0x06 | 0 1 000110 | 0x46 | `JNZL` | Jump long if not zero (pops condition, pops 2-byte address) |

#### Comparison

**ID 0x07:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x07 | 0 0 000111 | 0x07 | `CMPR` | Compare (byte) - 1-byte comparison type follows |
| E=0 S=1 ID=0x07 | 0 1 000111 | 0x47 | `CMPR` | Compare (word) - 1-byte comparison type follows |

**Comparison Types (immediate byte values):**

| Value | Symbol | Description | Result |
|-------|--------|-------------|--------|
| 0x00 | `==` or `EQ` | Equal | Pushes 1 if a == b, 0 otherwise |
| 0x01 | `!=` or `NE` | Not equal | Pushes 1 if a != b, 0 otherwise |
| 0x02 | `<` or `LT` | Less than | Pushes 1 if a < b, 0 otherwise |
| 0x03 | `>` or `GT` | Greater than | Pushes 1 if a > b, 0 otherwise |
| 0x04 | `<=` or `LE` | Less than or equal | Pushes 1 if a ≤ b, 0 otherwise |
| 0x05 | `>=` or `GE` | Greater than or equal | Pushes 1 if a ≥ b, 0 otherwise |

**Operation:**
```
CMPR <type>
Pops: b (top of stack), a (second on stack)
Compares: a <op> b
Pushes: 1 (true) or 0 (false)
```

**Example:**
```
push 3
push 4
CMPR !=    ( Compares 3 != 4, pushes 1 - true )
```

#### Stack manipulation

**ID 0x08:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x08 | 0 0 001000 | 0x08 | `PUSH1` | Push byte (1-byte immediate follows) |
| E=0 S=1 ID=0x08 | 0 1 001000 | 0x48 | `PUSH2` | Push word (2-byte immediate follows) |

**ID 0x09:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x09 | 0 0 001001 | 0x09 | `DROP1` | Remove top byte ( a:byte -- ) |
| E=0 S=1 ID=0x09 | 0 1 001001 | 0x49 | `DROP2` | Remove top word ( a:word -- ) |

**ID 0x0A:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x0A | 0 0 001010 | 0x0A | `DUP1` | Duplicate top byte ( a:byte -- a a ) |
| E=0 S=1 ID=0x0A | 0 1 001010 | 0x4A | `DUP2` | Duplicate top word ( a:word -- a a ) |

**ID 0x0B:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x0B | 0 0 001011 | 0x0B | `SWAP1` | Swap top two bytes ( a:byte b:byte -- b a ) |
| E=0 S=1 ID=0x0B | 0 1 001011 | 0x4B | `SWAP2` | Swap top two words ( a:word b:word -- b a ) |

**ID 0x0C:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x0C | 0 0 001100 | 0x0C | `NIP1` | Remove second byte ( a:byte b:byte -- b ) |
| E=0 S=1 ID=0x0C | 0 1 001100 | 0x4C | `NIP2` | Remove second word ( a:word b:word -- b ) |

**ID 0x0D:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x0D | 0 0 001101 | 0x0D | `OVER1` | Copy second byte to top ( a:byte b:byte -- a b a ) |
| E=0 S=1 ID=0x0D | 0 1 001101 | 0x4D | `OVER2` | Copy second word to top ( a:word b:word -- a b a ) |

**ID 0x0E:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x0E | 0 0 001110 | 0x0E | `ROT1` | Rotate top three bytes ( a:byte b:byte c:byte -- b c a ) |
| E=0 S=1 ID=0x0E | 0 1 001110 | 0x4E | `ROT2` | Rotate top three words ( a:word b:word c:word -- b c a ) |

**ID 0x0F:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x0F | 0 0 001111 | 0x0F | `PICK1` | Copy nth byte to top (pops index:byte, pushes nth byte) |
| E=0 S=1 ID=0x0F | 0 1 001111 | 0x4F | `PICK2` | Copy nth word to top (pops index:byte, pushes nth word) |

**ID 0x10:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x10 | 0 0 010000 | 0x10 | `POKE1` | Set nth byte (pops value:byte, pops index:byte) |
| E=0 S=1 ID=0x10 | 0 1 010000 | 0x50 | `POKE2` | Set nth word (pops value:word, pops index:byte) |

#### Arithmetic

Binary arithmetic operations. All operations pop their operands from the stack and push the result.

**ID 0x11:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x11 | 0 0 010001 | 0x11 | `ADD1` | Add two bytes (pops b:byte, pops a:byte, pushes a+b:byte) |
| E=0 S=1 ID=0x11 | 0 1 010001 | 0x51 | `ADD2` | Add two words (pops b:word, pops a:word, pushes a+b:word) |

**ID 0x12:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x12 | 0 0 010010 | 0x12 | `SUB1` | Subtract two bytes (pops b:byte, pops a:byte, pushes a-b:byte) |
| E=0 S=1 ID=0x12 | 0 1 010010 | 0x52 | `SUB2` | Subtract two words (pops b:word, pops a:word, pushes a-b:word) |

**ID 0x13:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x13 | 0 0 010011 | 0x13 | `MUL1` | Multiply two bytes (pops b:byte, pops a:byte, pushes a*b:byte) |
| E=0 S=1 ID=0x13 | 0 1 010011 | 0x53 | `MUL2` | Multiply two words (pops b:word, pops a:word, pushes a*b:word) |

**ID 0x14:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x14 | 0 0 010100 | 0x14 | `DIV1` | Divide two bytes (pops b:byte, pops a:byte, pushes a/b:byte) |
| E=0 S=1 ID=0x14 | 0 1 010100 | 0x54 | `DIV2` | Divide two words (pops b:word, pops a:word, pushes a/b:word) |

**ID 0x15:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x15 | 0 0 010101 | 0x15 | `MOD1` | Modulo two bytes (pops b:byte, pops a:byte, pushes a%b:byte) |
| E=0 S=1 ID=0x15 | 0 1 010101 | 0x55 | `MOD2` | Modulo two words (pops b:word, pops a:word, pushes a%b:word) |

**ID 0x16:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x16 | 0 0 010110 | 0x16 | `NEG1` | Negate byte (pops a:byte, pushes -a:byte) |
| E=0 S=1 ID=0x16 | 0 1 010110 | 0x56 | `NEG2` | Negate word (pops a:word, pushes -a:word) |

**ID 0x17:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x17 | 0 0 010111 | 0x17 | `ABS1` | Absolute value of byte (pops a:byte, pushes abs(a):byte) |
| E=0 S=1 ID=0x17 | 0 1 010111 | 0x57 | `ABS2` | Absolute value of word (pops a:word, pushes abs(a):word) |

**ID 0x18:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x18 | 0 0 011000 | 0x18 | `INC1` | Increment byte (pops a:byte, pushes a+1:byte) |
| E=0 S=1 ID=0x18 | 0 1 011000 | 0x58 | `INC2` | Increment word (pops a:word, pushes a+1:word) |

**ID 0x19:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x19 | 0 0 011001 | 0x19 | `DEC1` | Decrement byte (pops a:byte, pushes a-1:byte) |
| E=0 S=1 ID=0x19 | 0 1 011001 | 0x59 | `DEC2` | Decrement word (pops a:word, pushes a-1:word) |

#### Bitwise

Bitwise operations. All operations pop their operands from the stack and push the result.

**ID 0x1A:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x1A | 0 0 011010 | 0x1A | `AND1` | Bitwise AND of two bytes (pops b:byte, pops a:byte, pushes a&b:byte) |
| E=0 S=1 ID=0x1A | 0 1 011010 | 0x5A | `AND2` | Bitwise AND of two words (pops b:word, pops a:word, pushes a&b:word) |

**ID 0x1B:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x1B | 0 0 011011 | 0x1B | `OR1` | Bitwise OR of two bytes (pops b:byte, pops a:byte, pushes a\|b:byte) |
| E=0 S=1 ID=0x1B | 0 1 011011 | 0x5B | `OR2` | Bitwise OR of two words (pops b:word, pops a:word, pushes a\|b:word) |

**ID 0x1C:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x1C | 0 0 011100 | 0x1C | `NOT1` | Bitwise NOT of byte (pops a:byte, pushes ~a:byte) |
| E=0 S=1 ID=0x1C | 0 1 011100 | 0x5C | `NOT2` | Bitwise NOT of word (pops a:word, pushes ~a:word) |

**ID 0x1D:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x1D | 0 0 011101 | 0x1D | `XOR1` | Bitwise XOR of two bytes (pops b:byte, pops a:byte, pushes a^b:byte) |
| E=0 S=1 ID=0x1D | 0 1 011101 | 0x5D | `XOR2` | Bitwise XOR of two words (pops b:word, pops a:word, pushes a^b:word) |

**ID 0x1E:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x1E | 0 0 011110 | 0x1E | `SHL1` | Shift left byte (pops count:byte, pops value:byte, pushes value<<count:byte) |
| E=0 S=1 ID=0x1E | 0 1 011110 | 0x5E | `SHL2` | Shift left word (pops count:byte, pops value:word, pushes value<<count:word) |

**ID 0x1F:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x1F | 0 0 011111 | 0x1F | `SHR1` | Shift right byte (pops count:byte, pops value:byte, pushes value>>count:byte) |
| E=0 S=1 ID=0x1F | 0 1 011111 | 0x5F | `SHR2` | Shift right word (pops count:byte, pops value:word, pushes value>>count:word) |

**ID 0x20:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x20 | 0 0 100000 | 0x20 | `ROL1` | Rotate left byte (pops count:byte, pops value:byte, pushes value rotated left by count) |
| E=0 S=1 ID=0x20 | 0 1 100000 | 0x60 | `ROL2` | Rotate left word (pops count:byte, pops value:word, pushes value rotated left by count) |

**ID 0x21:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x21 | 0 0 100001 | 0x21 | `ROR1` | Rotate right byte (pops count:byte, pops value:byte, pushes value rotated right by count) |
| E=0 S=1 ID=0x21 | 0 1 100001 | 0x61 | `ROR2` | Rotate right word (pops count:byte, pops value:word, pushes value rotated right by count) |

#### Memory access

Memory load and store operations. Addresses are always 16-bit words.

**ID 0x22:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x22 | 0 0 100010 | 0x22 | `LOAD1` | Load byte from address (pops addr:word, pushes byte at addr) |
| E=0 S=1 ID=0x22 | 0 1 100010 | 0x62 | `LOAD2` | Load word from address (pops addr:word, pushes word at addr) |

**ID 0x23:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x23 | 0 0 100011 | 0x23 | `STORE1` | Store byte to address (pops value:byte, pops addr:word) |
| E=0 S=1 ID=0x23 | 0 1 100011 | 0x63 | `STORE2` | Store word to address (pops value:word, pops addr:word) |

**ID 0x24:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x24 | 0 0 100100 | 0x24 | `ILOAD1` | Indirect load byte (pops ptr:word, loads word at ptr as addr, pushes byte at addr) |
| E=0 S=1 ID=0x24 | 0 1 100100 | 0x64 | `ILOAD2` | Indirect load word (pops ptr:word, loads word at ptr as addr, pushes word at addr) |

**ID 0x25:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x25 | 0 0 100101 | 0x25 | `ISTORE1` | Indirect store byte (pops value:byte, pops ptr:word, loads word at ptr as addr, stores value at addr) |
| E=0 S=1 ID=0x25 | 0 1 100101 | 0x65 | `ISTORE2` | Indirect store word (pops value:word, pops ptr:word, loads word at ptr as addr, stores value at addr) |

**ID 0x26:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x26 | 0 0 100110 | 0x26 | `MEMCPY1` | Copy memory (pops dest:word, pops src:word, pops len:byte, copies len bytes) |
| E=0 S=1 ID=0x26 | 0 1 100110 | 0x66 | `MEMCPY2` | Copy memory (pops dest:word, pops src:word, pops len:word, copies len bytes) |

**ID 0x27:**

| Opcode | Binary | Hex | Mnemonic | Description |
|--------|--------|-----|----------|-------------|
| E=0 S=0 ID=0x27 | 0 0 100111 | 0x27 | `MEMSET1` | Fill memory (pops dest:word, pops value:byte, pops count:byte, fills count bytes with value) |
| E=0 S=1 ID=0x27 | 0 1 100111 | 0x67 | `MEMSET2` | Fill memory (pops dest:word, pops value:byte, pops count:word, fills count bytes with value) |

**Unused IDs (0x28-0x3F):**

IDs 0x28 through 0x3F are currently unassigned. Executing any of these opcodes will cause the VM to halt with an invalid opcode error, similar to the `INVALID` (0x00) opcode behavior.

## Binary file specification

### File Structure
The binary file uses a chunk-based format where sections are read linearly. Each chunk is self-describing, allowing for extensibility.

### File Header
```
Offset | Size | Field   | Description
-------|------|---------|---------------------------
0x00   | 4    | Magic   | File signature: "FRTH" (0x46525448)
0x04   | 2    | Version | Format version (e.g., 0x0100 = v1.0)
```

Total header size: 6 bytes

The magic number appears first so future versions can identify the file format, followed by the version number to handle any format changes.

### Chunk Format
After the header, the file contains a series of chunks:
```
[4-byte chunk type] [4-byte chunk size] [chunk data...]
```

- **Chunk Type:** 4-byte ASCII identifier (e.g., "CODE", "DEBG")
- **Chunk Size:** Size of chunk data in bytes (not including type and size fields)
- **Chunk Data:** The actual chunk payload

### Standard Chunk Types

#### CODE - Code Section
```
Type: "CODE" (0x434F4445)
Contains: Entry point and bytecode instructions
Required: No
```

**CODE Chunk Format:**
```
[4-byte: entry point offset] [bytecode instructions...]
```

The entry point is an absolute offset within the CODE chunk's data section where execution begins. An entry point of 0 means execution starts at the first byte after the entry point field (the first instruction).

#### COMP - Compression Metadata
```
Type: "COMP" (0x434F4D50)
Contains: Compressed binary data that expands into other chunks
Required: No (only if compression is used)
```

**COMP Chunk Format:**
```
[1-byte: compression method]
[4-byte: checksum]
[compressed data...]
```

**Compression Methods:**

| Value | Method   | Description |
|-------|----------|-------------|
| 0x01  | Huffman  | Huffman encoding |
| 0x02  | LZ77     | Dictionary-based compression |
| 0x03  | RLE      | Run-length encoding |
| 0xFF  | Reserved | Future compression methods |

**Checksum:**
The checksum is computed over the decompressed data using CRC32. After decompression, the VM computes the CRC32 of the decompressed data and compares it to the stored checksum to validate integrity.

**Loading Process:**
When the VM encounters a COMP chunk:
1. Read the compression method and checksum
2. Decompress the data using the specified method
3. Compute CRC32 of decompressed data and verify against checksum
4. The decompressed data contains additional chunks (CODE, DEBG, etc.)
5. Parse the decompressed data as a continuation of the file format
6. Process those chunks immediately

COMP chunks can appear anywhere in the file and are processed in the order they are encountered.

This allows compressed chunks to be stored efficiently while maintaining the chunk-based format after decompression.

#### DEBG - Debug Information
```
Type: "DEBG" (0x44454247)
Contains: Symbol names and source location mapping
Required: No
```

Format:
```
[4-byte: number of symbols]
For each symbol:
  [4-byte: hash]
  [4-byte: name length]
  [N bytes: UTF-8 name]
  
[4-byte: number of source mappings]
For each mapping:
  [4-byte: bytecode offset]
  [4-byte: source line]
  [4-byte: source column]
```

The debug section can be stripped from release builds for smaller file size.

### Example File Layout
```
[FRTH][0100]                              # Header: magic + version
[CODE][00000104][00000000][bytecode...]   # Code chunk: 260 bytes total (4-byte entry + 256 bytes code)
[DEBG][000001A0][debug data...]           # Debug chunk: 416 bytes
```

### Extensibility
- Unknown chunk types should be skipped by the VM
- Chunks can appear in any order after the header
- Future versions may define additional chunk types
- Tools can add custom chunks that the VM will ignore

## System Architecture

### Memory Model
- **Address width**: 16-bit
- **Address space**: 64 KB (65,536 bytes)
- **Address format**: 2 bytes (16 bits, little-endian)
- **Data widths**: 8/16-bit (determined by opcode size bit)
- **Maximum program size**: 64 KB

### Physical Addressing
```
Address Range: 0x0000 - 0xFFFF (64 KB)
```

All addresses (entry points, jumps, calls, memory operations) use 2-byte (16-bit) addressing.

## PNG Cartridge Format

Programs can be embedded in PNG images for easy sharing and distribution, similar to Pico-8 cartridges.

### Image Requirements
- **Format**: PNG with RGBA (32-bit color)
- **Color depth**: 8 bits per channel (R, G, B, A)
- **Size**: Any dimensions with sufficient capacity for the binary data

The aspect ratio of 432:607 (approximately 5:7) matches trading card dimensions and provides an aesthetically pleasing format.

### Embedding Method
The binary file is embedded using LSB (Least Significant Bit) steganography with mixed bit depths:
- **RGB channels**: 2 LSBs per channel (6 bits total)
- **Alpha channel**: 4 LSBs (4 bits)
- **Total per pixel**: 10 bits

### Capacity
Capacity depends on image size. With 10 bits per pixel (2+2+2+4 from RGBA LSBs):

```
Capacity formula: (Width × Height × 10) / 8 = Capacity in bytes

Example (432×607 trading card size):
262,224 pixels → 327,780 bytes (~320 KB)
  - Program size: up to 64 KB (CODE, COMP, DEBG chunks)
  - Assets: ~256 KB (sprites, maps, sounds, fonts, etc.)
```

### Embedding Process
1. Compile program to binary format (header + chunks)
2. Calculate required capacity: `(binary size × 8) / 10` pixels minimum
3. Create or load an RGBA PNG image
4. Validate image has enough pixels for the binary data
5. Convert binary to bit stream
6. Write bits sequentially across pixels:
   - 2 LSBs to R channel
   - 2 LSBs to G channel
   - 2 LSBs to B channel
   - 4 LSBs to A channel
7. Magic number "FRTH" appears in first pixels for validation
8. Save modified PNG as cartridge file

### Extraction Process
1. Load PNG image and verify it is RGBA format
2. Extract LSBs from each pixel sequentially:
   - 2 bits from R
   - 2 bits from G
   - 2 bits from B
   - 4 bits from A
3. Reconstruct bit stream into bytes
4. Verify "FRTH" magic number (first 4 bytes)
5. Parse binary file format (header + chunks)
6. Execute from CODE chunk entry point

### Visual Impact
- **RGB channels**: Each can shift by ±3 (minimal, generally imperceptible)
- **Alpha channel**: Can shift by ±15 (more noticeable but often acceptable)
- Images remain shareable on social media and forums
- Suitable for artwork, icons, or promotional images

### Benefits
- Share programs as visually appealing images
- Programs "download" by saving the image
- Works with any PNG-compatible platform
- Community can create custom artwork for programs
- Similar to Pico-8's cartridge system

## Language specification

### Comments
Comments are encapsulated in parentheses eg: `( this is a comment )`

### Literals
**Types:**
1. Integer
2. Character
3. String

#### Integer literals
Integer literals are hexadecimal numbers `0-9` `A-F | a-f` that can be up to `0xFFFF` and must start with `0-9` so the lexer knows it is a number and not an identifier eg: `A = 0A`. These are inlined into the bytecode.

**Size modifiers:**
Integer literals can have optional suffix modifiers `b` (byte) or `w` (word) to explicitly control size:
- No suffix: defaults to byte (8-bit) if value fits, otherwise word (16-bit)
- `b` suffix: force byte (8-bit) representation, truncates to lowest 8 bits if value > 0xFF
- `w` suffix: force word (16-bit) representation, zero-extends if value < 0x100

**Negative numbers:**
Negative integer literals use a `-` prefix. The compiler computes the two's complement representation.

Examples:
- `42` → 0x42 (byte, auto-sized)
- `42b` → 0x42 (byte, explicit)
- `42w` → 0x0042 (word, explicit)
- `-1` → 0xFF (byte, auto-sized)
- `-1b` → 0xFF (byte, explicit)
- `-1w` → 0xFFFF (word, explicit)
- `-5` → 0xFB (byte, auto-sized)
- `-100` → 0x9C (byte, fits in 8 bits)
- `-100w` → 0xFF9C (word, explicit)
- `FFFF` → 0xFFFF (word, auto-sized because > 0xFF)
- `FFw` → 0x00FF (word, explicit)
- `FFFFb` → 0xFF (byte, truncates to low byte)

#### Character literals
Character literals are demarkated by the `'` followed by any single non-whitespace ASCII/Unicode character. Whitespace after `'` is a compile error.

To represent whitespace characters, use hex literals:
- Space: `20` (0x20)
- Tab: `09` (0x09)
- Newline: `0A` (0x0A)

Examples:
- `'A` → 0x41 (character 'A')
- `'0` → 0x30 (character '0')
- `'"` → 0x22 (quote character)

Character literals are inlined into the bytecode as single byte values.

#### String literals
String literals are demarkated by the `"` and continue until the next space character. Spaces are **not** included in string literals automatically.

To include spaces in strings, insert the space byte `20` (0x20) explicitly where needed.

String literals (and character/integer literals) are **inlined into the bytecode as raw data**. They only get pushed onto the stack if preceded by a PUSH opcode.

Examples of inlined bytecode data:
- `"test 20 20 "data` → inlines bytes `[74 65 73 74 20 20 64 61 74 61]` ("test  data")
- `"hello 20 "world` → inlines bytes `[68 65 6C 6C 6F 20 77 6F 72 6C 64]` ("hello world")

Examples with PUSH opcodes (pushes onto stack):
- `PUSH "hello` → pushes the string "hello" onto the stack
- `PUSH 42` → pushes the byte 0x42 onto the stack
- `PUSH 'A` → pushes the byte 0x41 (character 'A') onto the stack

Literals without a preceding PUSH opcode are simply embedded as data in the bytecode and can be used for inline data tables, padding, or other non-stack purposes.

### Labels

#### Label types
##### Global labels
Global labels are defined with `:` followed by a letter or underscore, then any combination of letters, numbers, or underscores (case sensitive).

Example: `:_global_label_090909`

##### Local labels
Local labels are defined with `&` followed by a letter or underscore, then any combination of letters, numbers, or underscores (case sensitive).

Example: `&_local_label_090909`

#### Referencing labels
To reference a label you must use the `@` symbol followed by the label name, local or global.

Example: `@_local_label_090909`

This will inline the 2-byte address of that label into the bytecode if it exists.

##### Scoping and resolution of references
References using `@` first looks at the local scope for the label definition, allowing for shadowing of global labels. If the label cannot be found, then it searches the parent scope and so on until it either finds a matching label name or reaches the outermost scope. If no matching label is found at the global scope, a compiler error is reported to the user.
**Examples:**
```
:main
    push2 42
    trap 01 ( prints 42 as a character )
    &loop
        (does something)
    push2 @loop ( finds &loop in the current scope )
    jmp

:other_label
    push2 @loop ( Error: no local &loop, no global :loop )
    push2 @main ( finds global :main )
    jmp
```
### Padding
the special symbols `|` and `$` are used for absolute and relative padding respectivly 

#### Absolute padding `|`
when `|` is encountered directly followed by a number eg `|10` the compiler moves to position 0x10 or decimal 16 and then the code after this is written from that location eg:
```
|10
:main
push 42
```
will first `|10` move to byte 16 and then write the opcode for `push` and then inline the number `42` into the binary

#### Relative padding `$`
when `$` is encountered directly followed by a number eg: `$2` the compiler moves ahead relative to the current position by that amount eg:

```
|10 $2
:main
push 42
```
will first `|10` move to byte 16 and then `$2` move ahead two more bytes to byte 18 and then write the opcode for `push` and inline the number `42` into the binary
