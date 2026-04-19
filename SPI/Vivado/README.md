#  FPGA Hardware Implementation: SPI Communication Controller

##  Project Overview
This directory contains the core **RTL (Register Transfer Level) design assets** for an SPI (Serial Peripheral Interface) communication system implemented on the **Xilinx Basys 3 FPGA**. The project facilitates full-duplex, synchronized data exchange between two FPGA boards, featuring real-time input via switches and visual output via 7-segment displays.

---

##  Key Hardware Features
* **Full-Duplex RTL Engine**: Dedicated Master and Slave modules for simultaneous 8-bit data transmission and reception.
* **Robust Master FSM**: Implements a structured Finite State Machine with four states: `IDLE`, `START`, `DATA`, and `STOP`.
* **Reliable Slave Synchronization**: Features 3-stage synchronizers for `sclk`, `mosi`, and `cs_n` signals to eliminate metastability during cross-board communication.
* **Configurable Protocol**: Supports multiple SPI modes through adjustable **CPOL** (Clock Polarity) and **CPHA** (Clock Phase) settings.
* **Multiplexed Display System**: A custom FND controller translates 8-bit binary data into BCD format for real-time monitoring on the 4-digit 7-segment display.

---

##  System Architecture

### 1. SPI Master Board (`master_board.sv`)
* **Top Module**: `board_a_top`
* **Operation**: Reads data from 8 physical switches (`sw`) and triggers transmission using the `btn_start` input.
* **Control**: Uses an edge detector to ensure each button press initiates exactly one SPI transaction.
* **Constraint**: Mapped to **Basys-3-Master.xdc** with a 100MHz system clock on pin `W5`.

### 2. SPI Slave Board (`Slave_board.sv`)
* **Top Module**: `slave_board`
* **Operation**: Automatically captures incoming serial data from the Master on the rising edge of `sclk`.
* **Interaction**: Includes loopback capability where received data can be loaded into the Slave's TX buffer by pressing `btn_l`.
* **Output**: Instantiates `fnd_controller` to show the 8-bit received data on the board.

---

##  Design Module Breakdown

| Module | Filename | Description |
| :--- | :--- | :--- |
| **SPI Master** | `SPI_Master.sv` | Generates `sclk`, manages `cs_n` (Active Low), and performs bit-shifting for `mosi`/`miso`. |
| **SPI Slave** | `SPI_Slave.sv` | Synchronizes external signals and captures 8-bit data into the `rx_data` register. |
| **FND Controller** | `fnd_controller.sv` | Includes a 1kHz clock divider, digit multiplexer, and BCD-to-7-segment decoder. |
| **Constraints** | `Basys-3-Master.xdc` | Physical pin mapping for SPI signals (JA Pmod), Clock, Reset, and I/O devices. |

---

##  Hardware Interconnection (Pmod JA)
For physical board-to-board testing, connect the **JA Pmod headers** according to the following mapping:

| Signal | Basys 3 Pin (JA) | Description |
| :--- | :--- | :--- |
| **`cs_n_p`** | `J1` | Chip Select (Active Low) |
| **`mosi_p`** | `L2` | Master Out Slave In |
| **`miso_p`** | `J2` | Master In Slave Out |
| **`sclk_p`** | `G2` | Serial Clock |

> **Note**: Both boards must share a common **GND** connection to ensure signal stability.

---

##  How to Build
1. Open **Xilinx Vivado** and create a new RTL project.
2. Add all `.sv` files from the `Vivado` directory.
3. Import `Basys-3-Master.xdc` as the target constraint file.
4. Set the desired top module (`board_a_top` or `slave_board`) in the Hierarchy tab.
5. Run **Synthesis** → **Implementation** → **Generate Bitstream**.
