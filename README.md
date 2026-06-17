# SoC Communication Protocol Design & UVM-based Verification

![Vivado](https://img.shields.io/badge/Xilinx-Vivado-blue?logo=xilinx&logoColor=white)
![Vitis](https://img.shields.io/badge/Xilinx-Vitis-purple?logo=xilinx&logoColor=white)
![UVM](https://img.shields.io/badge/Verification-UVM_1.2-green)
![AXI](https://img.shields.io/badge/Bus-AMBA_AXI4--Lite-orange)
![Verilog](https://img.shields.io/badge/Language-Verilog_HDL-blueviolet)

## Project Overview
본 프로젝트는 시스템 반도체(SoC)의 핵심 구성 요소인 **SPI 및 I2C 통신 컨트롤러의 RTL 설계, AXI 버스 인터페이스 통합, Vitis 기반 HW-SW 공동 검증, 그리고 UVM(Universal Verification Methodology) 기반의 고급 검증**을 다룹니다.

Standalone 프로토콜 컨트롤러를 **AMBA AXI4-Lite 호환 Custom IP**로 패키징하여 Vivado Block Design 환경에 통합하였습니다. 더불어, **Vitis**를 통해 C 기반의 베어메탈(Bare-metal) 드라이버를 구현함으로써 하드웨어 레지스터 제어 및 HW-SW Co-Verification을 완벽히 수행하였으며, **UVM 1.2 방법론**을 적용하여 하드웨어 Corner Case까지 자동화된 환경에서 검증을 완료했습니다.

---

## Key Engineering Highlights

* **SoC Integration & Vivado AXI IP Flow**: Standalone 프로토콜 모듈을 AMBA AXI4-Lite 인터페이스 기반의 구조로 설계하고, **Vivado IP Packager**를 통해 Custom IP화했습니다. 이를 IP Integrator에서 Block Design으로 구성하여 프로세서 시스템과의 확장성을 확보했습니다.
* **Hardware-Software Co-Design (Vitis)**: Vivado에서 내보낸 Hardware Architecture (`.xsa`)를 기반으로 **Vitis** 환경에서 C 언어 기반의 베어메탈 드라이버 및 애플리케이션 코드를 작성했습니다. 메모리 맵 레지스터(MMIO) 읽기/쓰기를 통해 실제 하드웨어의 동작을 소프트웨어 레벨에서 통합 검증했습니다.
* **Advanced UVM Verification**: 에이전트(Agent), 드라이버(Driver), 모니터(Monitor), 스코어보드(Scoreboard) 등 계층적 구조를 가진 UVM 테스트벤치를 빌드하여 프로토콜 준수 여부에 대한 검증 효율성과 재사용성을 극대화했습니다.
* **Full Master-Slave Implementation**: SPI와 I2C 모두 Master와 Slave 모듈을 각각 설계하여 실제 칩 간 통신(Chip-to-Chip Communication) 환경을 완벽히 모사했습니다.
* **Environment Automation**: `Makefile` 및 `filelist.f`를 통한 시뮬레이션 환경 자동화 구축으로 명령어 한 줄로 전체 UVM 검증이 가능한 효율적인 프로세스를 마련했습니다.

---

## 📂 Repository Structure

프로젝트는 Vivado/Vitis 개발 플로우를 위한 **AXI_IP** 제품군과 Standalone 설계 및 검증 중심의 **SPI**, **I2C** 메인 폴더로 구성되어 있습니다.

```text
├── AXI_IP/                     # AXI-Lite Interface Integrated Custom IPs
│   ├── SPI/                    # SPI Master/Slave with AXI Interface (Vivado IP)
│   └── I2C/                    # I2C Master/Slave with AXI Interface (Vivado IP)
│
├── SPI/                        # Standalone SPI Protocol Project
│   ├── Vivado/                 # Hardware Design Assets (RTL & Basys-3 .xdc)
│   └── UVM_verification/       # Advanced Verification Environment (tb, Makefile)
│
├── I2C/                        # Standalone I2C Protocol Project
│   ├── Vivado/                 # Hardware Design Assets (RTL & Basys-3 .xdc)
│   └── UVM_verification/       # Advanced Verification Environment (tb, Makefile)
│
├── SPI_I2C_UVM.pdf             # Full Project Documentation & Verification Report
└── LICENSE                     # Project License
