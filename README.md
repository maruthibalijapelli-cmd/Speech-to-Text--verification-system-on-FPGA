# speech to Text verification on FPGA

## Overview

This project implements a **UART-based text comparison system on an FPGA** using Verilog.

The system receives two text inputs through UART:

1. **Reference word/sentence**
2. **Input word/sentence**

The FPGA stores the first input as the reference and compares the second input with it. The result is transmitted back through UART:

* `Y` → Match
* `N` → Not Match

The project uses a **100 MHz FPGA clock** and **115200 baud UART communication**.

---

## System Flow

```text
       PC / Python
           |
           | UART RX
           v
     +-------------+
     |  UART RX    |
     +-------------+
           |
           v
    +---------------+
    | Text Storage  |
    | Reference +   |
    | Input Buffer  |
    +---------------+
           |
           v
     +-------------+
     |  Comparator  |
     +-------------+
        |       |
       Y         N
        \       /
         v     v
     +-------------+
     |   UART TX   |
     +-------------+
           |
           | UART TX
           v
       PC / Python
```

---

## Features

* UART communication at **115200 baud**
* FPGA clock frequency: **100 MHz**
* UART configuration: **8N1**

  * 8 data bits
  * No parity
  * 1 stop bit
* Receives ASCII characters through UART
* Stores up to **16 characters**
* Ignores selected punctuation:

  * `.`
  * `,`
  * `!`
  * `?`
* Converts uppercase characters to lowercase
* Compares reference and input strings
* Sends:

  * `Y` for matching text
  * `N` for non-matching text

---

## Modules

### 1. `uart_rx`

The `uart_rx` module receives serial data from the PC and converts it into an 8-bit parallel byte.

### UART Reception Process

```text
Idle
  |
  | Detect START bit
  v
Start Bit
  |
  | Sample at bit center
  v
8 Data Bits
  |
  v
Stop Bit
  |
  v
rx_data + rx_done
```

### Important Signals

| Signal         | Description                         |
| -------------- | ----------------------------------- |
| `clk`          | FPGA clock                          |
| `rx`           | UART serial input                   |
| `rx_data[7:0]` | Received ASCII character            |
| `rx_done`      | Pulses high when a byte is received |

For a 100 MHz clock and 115200 baud:

```text
BAUD_DIV = 100,000,000 / 115,200
         ≈ 868 clock cycles/bit
```

---

### 2. `uart_tx`

The `uart_tx` module converts an 8-bit parallel byte into serial UART data.

### UART Transmission Format

```text
Idle | Start | D0 D1 D2 D3 D4 D5 D6 D7 | Stop
  1      0        Data Bits                1
```

The data is transmitted **LSB first**, as required by standard UART communication.

### Important Signals

| Signal         | Description                       |
| -------------- | --------------------------------- |
| `clk`          | FPGA clock                        |
| `tx_start`     | Starts transmission               |
| `tx_data[7:0]` | Byte to transmit                  |
| `tx`           | UART serial output                |
| `tx_done`      | Indicates transmission completion |

---

### 3. `top`

The `top` module connects the UART receiver, text storage, comparison logic, and UART transmitter.

The main states are:

```text
RECEIVE
   |
   | First Enter
   v
Store Reference
   |
   | Second Enter
   v
COMPARE
   |
   +---- Match ------> Send 'Y'
   |
   +---- No Match --> Send 'N'
   |
   v
RECEIVE
```

---

## Text Processing

The FPGA performs basic text preprocessing before comparison.

### Uppercase Conversion

For example:

```text
HELLO
```

is converted to:

```text
hello
```

The conversion is performed using the ASCII relationship:

```text
'A' + 32 = 'a'
'B' + 32 = 'b'
...
'Z' + 32 = 'z'
```

### Punctuation Removal

The following characters are ignored:

```text
?
.
,
!
```

For example:

```text
Hello!
```

is stored as:

```text
hello
```

---

## Example

### First UART Input

```text
Hello World
```

Press **Enter**.

The FPGA stores:

```text
hello world
```

as the reference string.

### Second UART Input

```text
HELLO WORLD!
```

Press **Enter**.

After preprocessing:

```text
hello world
```

The FPGA compares both strings.

### Output

```text
Y
```

---

## Non-Matching Example

Reference:

```text
Hello World
```

Input:

```text
Hello FPGA
```

Comparison:

```text
hello world
hello fpga
```

Output:

```text
N
```

---

## Memory Structure

The design uses two arrays:

```verilog
reg [7:0] ref_word [0:15];
reg [7:0] inp_word [0:15];
```

Each array can store up to **16 ASCII characters**.

```text
ref_word[0]  -> First character
ref_word[1]  -> Second character
...
ref_word[15] -> Sixteenth character
```

The same structure is used for the input string.

---

## Hardware Interface

The top module uses three main signals:

```verilog
input  clk;
input  UART_rxd;
output UART_txd;
```

### Connections

| FPGA Signal | Connection        |
| ----------- | ----------------- |
| `clk`       | FPGA system clock |
| `UART_rxd`  | USB-UART / PC TX  |
| `UART_txd`  | USB-UART / PC RX  |

The UART connection is crossed:

```text
PC TX  --------> FPGA RX
PC RX  <-------- FPGA TX
GND    --------- FPGA GND
```

---

## UART Configuration

```text
Baud Rate : 115200
Data Bits : 8
Parity    : None
Stop Bits : 1
```

Therefore:

```text
UART = 115200 8N1
```

---

## FPGA Implementation

### Clock

```text
Clock Frequency = 100 MHz
```

### UART Baud Divider

```text
BAUD_DIV = CLK_FREQ_HZ / BAUD_RATE

         = 100,000,000 / 115,200

         ≈ 868
```

Therefore, approximately **868 FPGA clock cycles represent one UART bit**.

---

## Required Files

The project contains the following Verilog modules:

```text
├── uart_rx.v
├── uart_tx.v
└── top.v
```

### `top.v`

Main control and comparison logic.

### `uart_rx.v`

UART receiver.

### `uart_tx.v`

UART transmitter.

---

## FPGA Design Flow

```text
Write Verilog
     |
     v
Create Vivado Project
     |
     v
Add RTL Sources
     |
     v
Add XDC Constraints
     |
     v
Run Synthesis
     |
     v
Run Implementation
     |
     v
Generate Bitstream
     |
     v
Program FPGA
     |
     v
Open Serial Terminal / Python
     |
     v
Send Reference Text
     |
     v
Send Input Text
     |
     v
Receive Y / N
```

---

## Testing

A serial terminal or Python program can be used to communicate with the FPGA.

Example:

```text
Reference:
hello world

Input:
HELLO WORLD!

FPGA:
Y
```

Another example:

```text
Reference:
hello world

Input:
hello fpga

FPGA:
N
```

---

## Limitations

* Maximum string length is **16 characters**.
* Only basic punctuation removal is implemented.
* Comparison is character-by-character.
* Spaces are currently treated as characters.
* No advanced speech or semantic comparison is performed.
* UART timing uses an integer baud divider, giving approximately 115200 baud.

---

## Project Objective

The main objective of this project is to demonstrate the implementation of:

* UART communication
* Serial-to-parallel conversion
* Parallel-to-serial conversion
* ASCII character processing
* FPGA memory/register arrays
* Finite-state-machine based control
* String comparison
* FPGA-to-PC communication

The project demonstrates how a PC can communicate with an FPGA through UART and how the FPGA can perform real-time digital processing on received data.

