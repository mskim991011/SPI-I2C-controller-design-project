#  Advanced I2C Functional Verification: UVM 1.2 Environment

##  Verification Overview
This directory implements a professional-grade functional verification environment for I2C Master and Slave controllers using **UVM (Universal Verification Methodology) 1.2**. The environment is engineered to validate complex bidirectional handshaking, 7-bit addressing, and real-time protocol compliance through an automated, coverage-driven pipeline.

By separating the testbench into reusable, transaction-level components, this environment ensures the I2C hardware remains robust across varied stimulus patterns and randomized bus conditions.

---

##  Key Verification Strategies

### 1. High-Fidelity Bus Modeling
* **Open-Drain Emulation**: Utilizes `tri1` net types and tri-state logic (`1'bz`) within the SystemVerilog interface to accurately model the physical I2C pull-up resistor behavior and signal contention.
* **Timing Accuracy**: Drivers are implemented with precise setup/hold time delays to simulate real-world clock synchronization and data stability requirements.

### 2. Constrained-Random Stimulus (CRV)
The environment employs `uvm_sequence` to generate 50+ randomized iterations per test run:
* **Targeted Addressing**: Sequences specifically target valid slave addresses (e.g., `7'h12`) to verify address matching logic.
* **Weighted Data Patterns**: Randomizes `wdata` payloads and R/W bits to stress-test the state transitions of the internal FSMs.
* **Corner-Case Testing**: Validates protocol stability under back-to-back transaction scenarios and randomized inter-transaction delays.

### 3. Automated Self-Checking Mechanism
* **Transaction-Level Scoreboard**: Acts as the "Golden Reference" by comparing the stimulus driven by the master sequencer against the data captured by the slave monitor.
* **Error Detection**: Any mismatch between `expected_data` and the actual `rx_data` captured from the bus immediately triggers a `UVM_ERROR` and fails the simulation.

---

##  UVM Component Architecture

###  Layered Agents (Master & Slave)
The testbench is divided into dedicated agents, each containing:
* **Sequencer (`sqr`)**: Manages the flow of `i2c_item` objects for the test scenario.
* **Driver (`drv`)**: 
    * **Master Driver**: Implements low-level protocol tasks including `send_byte`, `read_byte`, and `wait_ack`. It directly controls the `scl` and `sda` lines to initiate transactions.
    * **Slave Driver**: Responds to the Master's requests by providing the necessary `ACK/NACK` pulses and managing data line release.
* **Monitor (`mon`)**: A passive component that asynchronously samples the `scl` and `sda` pins. It reconstructs physical signal toggles into high-level `i2c_item` transactions for scoreboard analysis.

###  Environment & Test Infrastructure
* **UVM Environment**: Connects all monitors to the scoreboard via TLM (Transaction Level Modeling) analysis ports.
* **Test Layer**: Configures the virtual interfaces via `uvm_config_db`, manages simulation phases, and initiates the sequences to start the data flow.

---

##  Simulation & Debugging Workflow
Fully integrated with a **Makefile-based automation** pipeline supporting Synopsys VCS and Verdi.

### 1. Execution Guide
* **Run Simulation**: `make sim TESTNAME=i2c_slave_test SEED=1234`
* **Waveform Debugging**: `make vw` (Launches Verdi with `.fsdb` files to analyze Start/Stop conditions and FSM transitions).
* **Coverage Analysis**: `make vc` (Analyzes Line, Condition, FSM, and Toggle coverage to ensure no logic path is left unverified).

---

##  Verification Result Summary
At the conclusion of each test run, the scoreboard outputs a detailed summary via the `report_phase`:

* **Total Transactions**: Total number of successfully completed Start-to-Stop I2C sequences.
* **MATCH Count**: Transactions where data integrity was perfectly maintained (Actual == Expected).
* **MISMATCH Count**: Detected protocol or data corruption errors (Triggers `UVM_ERROR`).
* **FINAL STATUS**: Declares **"TEST PASSED"** only if zero mismatches are detected across all randomized iterations.
