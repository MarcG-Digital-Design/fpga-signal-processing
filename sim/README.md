# Simulation

This folder holds the testbenches of the design, block by block. It starts with the DAC interface, `pmod_da3`; the testbenches of the other blocks are added here as they are developed.

| File | Content |
| --- | --- |
| `tb_pmod_da3.vhd` | Self-checking testbench of `pmod_da3` |

The block under test, [`pmod_da3.vhd`](../rtl/final_design/pmod_da3.vhd), is in [`rtl/final_design/`](../rtl/final_design/) with the other VHDL sources of the design.

## pmod_da3: SPI master for the Pmod DA3

The block sends one 16-bit frame to the DAC (AD5541A) each time a new filtered sample is available.

| Port | Direction | Description |
| --- | --- | --- |
| `clk` | in | 125 MHz system clock |
| `RESET` | in | Synchronous reset, active high |
| `y_valid` | in | One-cycle pulse: a new sample is available |
| `Signal_filtered` | in | Filtered sample, signed Q15 (16 bits) |
| `da3_cs_n` | out | Chip select, active low |
| `da3_din` | out | Serial data, MSB first |
| `da3_sclk` | out | Serial clock, 500 kHz |
| `da3_ldac` | out | Tied low |

How it works:

- **State machine:** `IDLE` (waits for `y_valid`), `TRANSMISSION` (sends the 16 bits), `END_TRANSMISSION` (releases the chip select).
- **Serial clock:** SCLK is generated from the 125 MHz clock by a counter: 125 clock cycles per half-period, so 500 kHz.
- **SPI mode 0:** the DAC samples `da3_din` on the rising edge of SCLK; the data changes after the falling edge.
- **Data format:** the signed Q15 sample is converted to offset binary by inverting its most significant bit, since the AD5541A expects an unsigned code. Bits are sent MSB first.
- **Update of the output:** `da3_ldac` is tied low, so the DAC output updates on the rising edge of the chip select, at the end of the frame.
- **Timing budget:** a frame lasts 16 × 2 µs = 32 µs, far below the sample period (208 µs at 4800 Hz).

## tb_pmod_da3: testbench

The testbench is self-checking. A model of the DAC rebuilds the 16-bit word sent on the bus, and two checkers watch the serial clock. At the end, one verdict covers all of them: `*** TEST PASSED ***`, or a failure with the error counts.

**Checked automatically:**

| Check | Expected |
| --- | --- |
| 16-bit word received by the DAC model | the input sample with its MSB inverted (offset binary) |
| SCLK period | exactly 2 µs (250 clock cycles), i.e. 500 kHz |
| SCLK rising edges per frame | exactly 16 (neither more nor fewer) |

Each automatic check was validated on a deliberately broken version of the module and was seen to fail.

**Checked on the waveform:** the duration of the chip select (about 32 µs) and the level of `da3_ldac` (always low).

Six samples are sent, including the extreme values:

| Input (signed Q15) | Meaning | Expected word (offset binary) |
| --- | --- | --- |
| `0xA5A5` | arbitrary pattern | `0x25A5` |
| `0x1234` | arbitrary pattern | `0x9234` |
| `0xFFFF` | −1 LSB | `0x7FFF` |
| `0x0000` | zero | `0x8000` |
| `0x7FFF` | positive full scale | `0xFFFF` |
| `0x8000` | negative full scale | `0x0000` |

## Running the simulation

In Vivado, add `rtl/final_design/pmod_da3.vhd` and `sim/tb_pmod_da3.vhd`, set `tb_pmod_da3` as the simulation top, and run for at least 310 µs (six frames, each followed by a 50 µs wait). The result appears in the Tcl console.
