# FPGA FIR Low-Pass Filter for Zybo Z7-10

This repository will contain a verified FPGA signal-processing chain for the Digilent Zybo Z7-10:

```text
analog input -> Pmod AD5 -> FPGA FIR filter -> Pmod DA3 -> analog output
```

The repository is currently at the **project skeleton** stage. No historical RTL has been imported yet. The legacy projects remain read-only references and are documented in [`docs/historical-inventory.md`](docs/historical-inventory.md).

## Target platform

| Item | Target |
| --- | --- |
| FPGA board | Digilent Zybo Z7-10 |
| FPGA device | AMD/Xilinx XC7Z010 |
| Fabric clock | 125 MHz (8 ns period) |
| ADC module | Digilent Pmod AD5, AD7193, 24-bit sigma-delta ADC |
| DAC module | Digilent Pmod DA3, AD5541A, 16-bit DAC |
| HDL | VHDL |
| FPGA tool | Vivado |

The achievable sampling rate, numeric representation, filter response, and acceptance thresholds must be agreed and recorded before RTL development starts. See [`docs/requirements.md`](docs/requirements.md).

## Repository layout

```text
constraints/        Board and timing constraints
docs/               Requirements, design notes, and verification evidence
matlab/             Filter design and reference-model scripts
reports/            Deliberately exported timing and utilization reports
rtl/adc/            Pmod AD5 interface
rtl/dac/            Pmod DA3 interface
rtl/fir/            FIR datapath and control
rtl/top/            Integrated top level
scripts/            Reproducible Vivado and simulation scripts
sim/adc/            ADC interface testbench
sim/dac/            DAC interface testbench
sim/fir/            FIR testbench and reference vectors
sim/integration/    End-to-end simulation
vivado/             Reproducible project-generation entry point
```

## Planned verification sequence

1. Freeze measurable requirements and numeric formats.
2. Simulate and verify the AD5 SPI interface.
3. Simulate and verify the DA3 SPI interface.
4. Simulate and verify the FIR against an independent reference model.
5. Integrate the `AD5 -> FIR -> DA3` chain.
6. Implement with a real 125 MHz clock constraint and archive timing/resource reports.
7. Validate the hardware with ILA and an Analog Discovery instrument.


