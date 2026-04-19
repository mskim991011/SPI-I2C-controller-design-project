#  FPGA Hardware Implementation: I2C Communication Controller

##  Project Overview
This repository contains the core **RTL (Register Transfer Level) design assets** for an I2C (Inter-Integrated Circuit) communication system implemented on the **Xilinx Basys 3 FPGA**. The project facilitates a complete Master-Slave handshake protocol, supporting 7-bit addressing and bidirectional data transfer. The system is verified through real-time hardware interaction, using switches for data input and 7-segment displays (FND) for visual verification.

---

## Key Hardware Features
* **Standard-Mode I2C Controller**: Implements a 100kHz SCL clock frequency based on a 100MHz system clock.
* **Master FSM Logic**: Employs a robust Finite State Machine with states: `IDLE`, `START`, `WAIT_CMD`, `DATA`, `DATA_ACK`, and `STOP`.
* **Slave Address Recognition**: The Slave module is configured with a specific 7-bit address (`7'h12`) and supports both Write and Read operations.
* **Synchronized Signal Sampling**: Utilizes 3-stage synchronizers for `scl` and `sda` lines to prevent metastability and ensure reliable Start/Stop condition detection.
* **Bidirectional SDA Handling**: Implements tri-state buffer logic (`1'bz`) to manage the shared SDA line according to I2C bus specifications.
* **Visual Monitoring**: Features a multiplexed FND controller that decodes received I2C data into a 4-digit 7-segment display output.

---

##  System Architecture

### 1. I2C Master Board (`top_master.sv`)
* **Top Module**: `top_master`
* **Operation**: Reads 8-bit data from slide switches (`sw`) and initiates Write/Read commands via physical buttons (`btn_write`, `btn_read`).
* **Command Sequence**: Automatically manages the `START` → `ADDRESS+W/R` → `DATA` → `STOP` sequence.
* **Constraint**: Mapped to **Basys-3-Master.xdc** using the **JB Pmod header** for bus signals.

### 2. I2C Slave Board (`i2c_slave.sv`)
* **Top Module**: `top_slave_board`
* **Operation**: Monitors the bus for its unique slave address. Upon a match, it handles data reception (Write) or transmission (Read) based on the R/W bit.
* **FND Visualization**: Instantiates the `fnd_controller` to display received 8-bit data values in real-time.
* **Handshaking**: Automatically generates `ACK` pulses upon successful address and data byte reception.

---

##  Design Module Breakdown

| Module | Filename | Description |
| :--- | :--- | :--- |
| **I2C Master** | `I2C_master.sv` | Core logic for SCL generation, Start/Stop condition control, and byte-level transmission. |
| **I2C Slave** | `i2c_slave.sv` | Slave logic including address matching, ACK generation, and SDA tri-state management. |
| **FND Controller** | `fnd_controller.sv` | Manages 1kHz multiplexing for the 4-digit display and BCD-to-7-segment decoding. |
| **Constraints** | `Basys-3-Master.xdc` | Physical pin mapping for SCL (A14) and SDA (A16) on the JB Pmod header. |

---

##  Hardware Interconnection (Pmod JB)
For physical communication between two Basys 3 boards, connect the **JB Pmod headers** as follows:

| Signal | Basys 3 Pin (JB) | Pmod JB Label | Direction |
| :--- | :--- | :--- | :--- |
| **`SCL`** | `A14` | JB1 | Master Out / Slave In |
| **`SDA`** | `A16` | JB2 | Bidirectional |
| **`GND`** | `GND` | GND | Common Ground |

> **Note**: Both boards must share a common **GND** for signal integrity. The SDA line is handled as an open-drain signal using internal pull-up configurations or external resistors where necessary.

---

##  How to Build
1. Open **Xilinx Vivado** and create a new RTL project.
2. Add all `.sv` source files for the I2C project.
3. Import `Basys-3-Master.xdc` and ensure `scl` and `sda` are mapped to the correct Pmod JB pins.
4. Set the top module (`top_master` for the Master board or `top_slave_board` for the Slave board).
5. Run **Synthesis** → **Implementation** → **Generate Bitstream**.
