# AXI4-Lite Integrated Communication IPs (SPI & I2C)

본 디렉토리는 SPI 및 I2C 통신 컨트롤러를 **AMBA AXI4-Lite 버스 인터페이스**와 통합하여, 자일링스(Xilinx) **Vivado 및 Vitis** 환경에서 하드웨어-소프트웨어 공동 설계(HW/SW Co-Design)가 가능하도록 고도화한 Custom IP 패키지입니다.

---

## 1. Why AXI4-Lite? (in Vivado)

SoC 설계에서 커스텀 하드웨어(RTL)를 프로세서(예: MicroBlaze, Zynq ARM Cortex)와 통신하게 하려면 표준화된 버스 규격이 필요합니다. 본 프로젝트는 주변장치(Peripheral) 제어에 가장 최적화된 **AXI4-Lite** 프로토콜을 채택했습니다.

* **Lightweight & Efficient**: 대용량 데이터를 고속으로 쏘는 버스트(Burst) 전송이 필요한 메모리 제어와 달리, 통신 모듈의 레지스터 제어는 단일 데이터 전송(Single Transfer)이 주를 이룹니다. AXI4-Lite는 이러한 32-bit 레지스터 제어에 특화되어 리소스 소모가 적고 효율적입니다.
* **Memory-Mapped I/O (MMIO)**: 프로세서가 특정 메모리 주소에 읽기/쓰기 명령을 내리면, AXI 버스를 통해 해당 주소에 매핑된 Custom IP의 내부 레지스터(Control/Status/Data) 값이 변경되며 동작을 수행합니다.

### AXI4-Lite 5-Channel Architecture

IP 내부 인터페이스에 AXI4-Lite의 5개 독립적인 채널을 구현하여 Handshaking(`VALID` & `READY`) 기반의 안정적인 트랜잭션을 설계했습니다.
* **Write Channels**: `AW` (Write Address), `W` (Write Data), `B` (Write Response)
* **Read Channels**: `AR` (Read Address), `R` (Read Data)

---

##  2. Custom IP Packaging & Block Design (Vivado)

순수 RTL 코드로 작성된 통신 모듈을 Vivado의 **IP Packager**를 활용하여 SoC 시스템에 즉시 플러그인(Plug-in)할 수 있는 형태로 변환했습니다.

1. **Interface Inference**: Vivado가 RTL 코드 내의 AXI-Lite 포트 이름들(`s_axi_awaddr`, `s_axi_wdata` 등)을 인식하여 하나의 규격화된 버스 인터페이스로 그룹화합니다.
2. **Block Design Integration**: IP Integrator 환경에서 프로세서의 Master 버스와 Custom IP의 Slave 버스를 연결합니다.
3. **Address Editor**: 프로세서가 IP에 접근할 수 있도록 Base Address(예: `0x44A00000`)와 Range를 할당받습니다. 이 주소는 이후 소프트웨어(Vitis)에서 하드웨어를 제어하는 고유 키(Key)가 됩니다.

---

## 3. HW/SW Co-Verification Flow (Vitis)

하드웨어 레지스터 맵 설계와 타이밍 검증이 완료된 후, Vivado에서 **Hardware Export(`.xsa`)** 파일을 생성하여 Vitis로 전달(Handoff)합니다. 이를 통해 소프트웨어 엔지니어 관점에서 하드웨어를 제어하는 검증을 수행했습니다.

### The Vivado-to-Vitis Handoff
1. **`.xsa` Import**: Vivado에서 정의한 하드웨어 아키텍처 정보(메모리 맵 주소, 연결된 IP 종류 등)를 Vitis가 읽어옵니다.
2. **BSP (Board Support Package) Generation**: Vitis는 `.xsa`를 바탕으로 `xparameters.h`라는 헤더 파일을 자동 생성합니다. 이 파일에는 Vivado의 Address Editor에서 할당했던 Custom IP의 주소값들이 C 매크로 상수로 정의되어 있습니다.

### Bare-metal C Driver Implementation
자동 생성된 `xparameters.h`와 Xilinx 기본 I/O 함수를 활용하여, IP 내부 레지스터를 직접 제어하는 베어메탈 드라이버를 구현했습니다.

```c
#include "xparameters.h"
#include "xil_io.h"

// Vivado Address Editor에서 할당되어 BSP에 자동 생성된 주소
#define SPI_IP_BASEADDR XPAR_CUSTOM_SPI_0_S00_AXI_BASEADDR 

// Custom IP Register Offsets
#define CR_OFFSET       0x00  // Control Register
#define TX_DATA_OFFSET  0x08  // Write Data Register

void SPI_Transmit(uint8_t data) {
    // 1. 전송할 데이터를 TX 레지스터에 쓰기 (AXI Write Data 채널을 통해 하드웨어로 전달됨)
    Xil_Out32(SPI_IP_BASEADDR + TX_DATA_OFFSET, data);
    
    // 2. Control Register의 Start 비트를 1로 셋팅하여 통신 시작 명령 전달
    Xil_Out32(SPI_IP_BASEADDR + CR_OFFSET, 0x01); 
}
