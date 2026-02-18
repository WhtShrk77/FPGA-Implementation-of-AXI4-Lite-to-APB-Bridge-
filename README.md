# Design and FPGA Implementation of an AXI4-Lite to APB Bridge

This project details the design and FPGA implementation of an AXI4-Lite to APB protocol bridge. It facilitates communication between high-speed AXI4-Lite master interfaces and low-power APB peripherals in System-on-Chip (SoC) environments.



## Project Overview
The bridge performs protocol translation, address decoding, and data multiplexing to ensure seamless interaction between heterogeneous bus protocols. This implementation specifically targets the **Nexys A7 FPGA** board, addressing practical considerations like timing closure and resource optimization.

### Key Features
* **Modular RTL Design**: Written in Verilog HDL supporting four independent APB slaves.
* **Standard Compliance**: State machines follow AMBA specifications for both AXI4-Lite and APB protocols.
* **Timing Optimized**: Includes pipelined data paths and one-hot FSM encoding to meet high-frequency hardware constraints.

## Architecture and Design
The modular architecture consists of four primary components:
1. **AXI-to-Request Converter**: A 7-state FSM handling AXI4-Lite slave protocol operations.
2. **APB Master Controller**: A 3-state FSM managing APB transactions (IDLE, SETUP, ACCESS).
3. **Bridge Core Integration**: Connects the converter and master modules to manage data flow.
4. **FPGA Top-Level**: Provides I/O mapping for the Artix-7 FPGA, clock generation, and reset synchronization.



### Memory Map
The address decoder uses bits [19:16] of the AXI address bus to select peripherals, allocating 64 KB address blocks to each slave:

| Peripheral | Base Address | Range |
| :--- | :--- | :--- |
| **Slave 0 (UART)** | `0x4000_0000` | 0x00000 - 0x0FFFF |
| **Slave 1 (GPIO)** | `0x4001_0000` | 0x10000 - 0x1FFFF |
| **Slave 2 (SPI)** | `0x4002_0000` | 0x20000 - 0x2FFFF |
| **Slave 3 (Timer)** | `0x4003_0000` | 0x30000 - 0x3FFFF |

## Implementation Results
The design was synthesized and implemented using **Xilinx Vivado** targeting the **Artix-7 XC7A100T-CSG324**.

### Resource Utilization
* **LUTs**: 108 (0.17%)
* **Flip-Flops**: 657 (0.52%)
* **I/O Pins**: 88 (41.90%)
* **Total On-Chip Power**: 0.101 W

### Timing Analysis (Target: 66.67 MHz)
* **Worst Negative Slack (WNS)**: 9.122 ns
* **Worst Hold Slack (WHS)**: 0.022 ns
* **Theoretical Max Frequency**: ~170 MHz

## Verification
Functional verification was performed using a self-checking testbench.

| Test Case | Status |
| :--- | :--- |
| UART R/W Test | **PASS** |
| GPIO R/W Test | **PASS** |
| SPI R/W Test | **PASS** |
| Timer R/W Test | **PASS** |
| Back-to-Back Writes | **PASS** |
| Invalid Address Read | **FAIL** |

## Tools Used
* **HDL**: Verilog
* **Simulation**: Icarus Verilog / GTKWave
* **Synthesis**: Xilinx Vivado
* **Hardware**: Nexys A7 (Artix-7 FPGA)

---
*Submitted by Vaisakh Melaveetil Shaju - Manipal Institute of Technology, Bengaluru.*
