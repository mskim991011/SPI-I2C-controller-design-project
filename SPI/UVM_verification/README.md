#  Advanced Functional Verification: SPI UVM Environment

##  Verification Overview
This repository implements a high-fidelity verification environment for SPI Master and Slave controllers using **UVM (Universal Verification Methodology) 1.2**. The primary goal is to achieve 100% functional reliability through constrained-random stimulus, automated self-checking, and comprehensive coverage analysis.

By separating the testbench into reusable components, this environment allows for rapid regression testing and ensures that the RTL design adheres strictly to the SPI protocol specifications under various corner-case scenarios.

---

##  Key Verification Strategies

### 1. Constrained-Random Stimulus Generation
Instead of simple directed tests, this environment utilizes **Constrained-Random Verification (CRV)** to explore the state space of the design-under-test (DUT) more effectively. 
* **Data Diversity**: Using `spi_seq_item`, we randomize 8-bit data with specific weighted distributions:
    * **Extreme Patterns**: All-Zeros (0x00) and All-Ones (0xFF) to verify signal range.
    * **Toggle Patterns**: 0x55 and 0xAA to stress-test bit transitions and power integrity.
    * **Standard Range**: 0x01 to 0xFE to ensure general data integrity across 50+ iterations.

### 2. Automated Self-Checking (Scoreboard)
The **Scoreboard** acts as the final judge of correctness. It implements a non-intrusive checking mechanism:
* **Real-time Comparison**: It captures the "Expected Data" from the Driver/Sequence and the "Actual Data" monitored from the physical bus.
* **Immediate Flagging**: Any bit-level mismatch during the transfer immediately triggers a `UVM_ERROR`, ensuring no bug goes unnoticed.
* **Detailed Reporting**: In the `report_phase`, it provides a crystal-clear summary of Total Transactions, Match counts, and Mismatch counts.

---

##  UVM Component Hierarchy

###  Agents (Master & Slave Agents)
Each agent encapsulates a Sequencer, Driver, and Monitor to handle a specific side of the SPI bus:
* **Sequencer (`sqr`)**: Orchestrates the flow of `spi_seq_item` objects.
* **Driver (`drv`)**: 
    * **In Master Test**: Emulates a Slave device by responding to `sclk` and `cs_n` to drive `miso`.
    * **In Slave Test**: Emulates a Master device by generating `sclk`, `mosi`, and `cs_n` with precise setup/hold timing.
* **Monitor (`mon`)**: Passively samples the bus signals. It uses the virtual interface to observe signal toggles and reconstructs them into high-level transactions.

###  Environment (`env`) & Test (`test`)
* **Environment**: Connects the Agents to the Scoreboard via TLM (Transaction Level Modeling) analysis ports.
* **Test Layer**: Controls the simulation phases, manages the virtual interface through the `uvm_config_db`, and initiates sequences to start the data flow.

---

##  Simulation & Automation Pipeline

The environment is fully integrated with a **Makefile-based workflow** for professional EDA tool support (Synopsys VCS & Verdi):

### 1. Execution Commands
* **Run Test**: `make sim TESTNAME=slave_test SEED=1234` (Supports random seed variation for regression).
* **Waveform Debug**: `make vw` (Launches Verdi with `dump.fsdb` for signal-level debugging).
* **Coverage View**: `make vc` (Analyzes collected coverage data).

### 2. Coverage-Driven Verification (CDV)
We monitor multiple coverage metrics to ensure the "dark corners" of the design are tested:
* **Code Coverage**: Line, Condition, and Toggle coverage for RTL logic.
* **FSM Coverage**: Ensures all states (`IDLE`, `START`, `DATA`, `STOP`) and transitions in the Master/Slave FSM are exercised.
* **Assertion Coverage**: SVA (SystemVerilog Assertions) check for protocol violations (e.g., `cs_n` must not toggle during a 8-bit transfer).

---

##  Verification Result Summary
At the conclusion of every simulation, the environment generates a **Verification Summary Report**:

* **Total Transactions**: Total number of 8-bit packets processed.
* **MATCH Count**: Successfully verified transactions with zero errors.
* **MISMATCH Count**: Number of failed comparisons (Triggers `UVM_ERROR`).
* **TEST STATUS**: A final **"TEST PASSED"** or **"TEST FAILED"** banner based on the scoreboard results.
