#  SoC Communication Protocol Design & UVM-based Verification

##  Project Overview
본 프로젝트는 시스템 반도체(SoC)의 핵심 구성 요소인 **SPI 및 I2C 통신 컨트롤러의 RTL 설계와 UVM(Universal Verification Methodology) 기반의 고급 검증**을 다룹니다. 

단순한 하드웨어 구현을 넘어, 현업 수준의 **UVM 1.2 방법론**을 적용하여 재사용 가능하고 자동화된 검증 환경을 구축했습니다. 이를 통해 다양한 시나리오에서의 프로토콜 준수 여부를 완벽하게 검증하였습니다.

---

##  Key Engineering Highlights
* **UVM Methodology Application**: 에이전트(Agent), 드라이버(Driver), 모니터(Monitor) 등 계층적 구조를 가진 UVM 테스트벤치를 구축하여 검증의 효율성과 재사용성을 극대화했습니다.
* **Full Master-Slave Implementation**: SPI와 I2C 모두 Master와 Slave 모듈을 각각 설계하여 실제 칩 간 통신(Chip-to-Chip Communication) 환경을 완벽히 모사했습니다.
* **Hardware-Software Co-Verification**: 
    * **Vivado**: 실제 FPGA 보드(Basys-3) 환경에 맞춘 제약 사항(`*.xdc`)을 반영하여 합성을 진행했습니다.
    * **Automation**: `Makefile` 및 `filelist.f`를 통한 시뮬레이션 환경 자동화 구축으로 효율적인 검증 프로세스를 마련했습니다.
* **Robust RTL Design**: Clock 분주기, FSM(Finite State Machine), 시프트 레지스터 등을 활용한 안정적인 프로토콜 제어 로직을 구현했습니다.

---
 
## 📂 Repository Structure

프로젝트는 **SPI**와 **I2C** 두 개의 메인 폴더로 구성되어 있으며, 각 폴더 내부에 설계 및 검증 자산이 독립적으로 관리됩니다.

```text
├── SPI/                        # SPI Protocol Project
│   ├── Vivado/                 # Hardware Design Assets
│   │   ├── master/             # SPI Master RTL & Basys-3-Master.xdc
│   │   └── slave/              # SPI Slave RTL & Basys-3-Slave.xdc
│   └── UVM_verification/       # Advanced Verification Environment
│       ├── rtl/                # Verification-ready RTL source (Master, Slave, etc.)
│       ├── tb/                 # UVM Testbench (Agents, Seqs, etc.)
│       ├── Makefile            # Simulation script
│       └── filelist.f          # Tool-command file list
│
└── I2C/                        # I2C Protocol Project
    ├── Vivado/                 # Hardware Design Assets
    │   ├── master/             # I2C Master RTL & Basys-3-Master.xdc
    │   └── slave/              # I2C Slave RTL & Basys-3-Slave.xdc
    └── UVM_verification/       # Advanced Verification Environment
        ├── rtl/                # Handshaking-integrated RTL
        ├── tb/                 # Address-matching & ACK/NACK TB
        ├── Makefile            # Simulation script
        └── filelist.f          # Tool-command file list
