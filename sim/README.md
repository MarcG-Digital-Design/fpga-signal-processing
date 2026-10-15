# Simulation

Each block of the design is simulated on its own before being integrated into the full chain. A block is only used in the top level once its testbench passes. This follows the unit-test level of the V-cycle described in the [main README](../README.md).

| File | Role |
| --- | --- |
| [`pmod_da3.vhd`](pmod_da3.vhd) | Block under test: SPI driver of the Pmod DA3 |
| [`tb_pmod_da3.vhd`](tb_pmod_da3.vhd) | Its testbench |

## pmod_da3

### Simulation

The testbench is self-checking: it uses assertions, so the simulator reports an error as soon as something is wrong and prints `*** TEST PASSED ***` at the end only if every check succeeded.

**Block design**

![pmod_da3 FSM](../docs/img/FSM_spi_da3.png)

**Simulation waveforms**

![pmod_da3 simulation](../docs/img/sim_pmod_da3.png)

### Validation on the board

Once the simulation passed, the block was tested on the Zybo Z7-10: a square-wave generator feeds the Pmod DA3, and the signals are observed with the Analog Discovery 3.

**DA3 output**: a 50 Hz square wave between 0 V and about 2.5 V (49.999 Hz, 50 % duty cycle measured).

![DA3 output on the Analog Discovery 3](../docs/img/da3_square_wave_ad3.png)

**SCLK**: one burst of 16 clock pulses per sample, one for each data bit. The bursts repeat every sample period (about 208 µs, 4.8 kHz).

![SCLK on the Analog Discovery 3](../docs/img/da3_sclk_ad3.png)

## Running the simulation

In Vivado, add both files, set `tb_pmod_da3` as the top module and run the behavioral simulation (about 310 µs).