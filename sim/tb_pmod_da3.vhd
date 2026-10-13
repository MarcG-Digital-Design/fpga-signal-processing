----------------------------------------------------------------------------------
-- Testbench for the pmod_da3 module (SPI driver for the Pmod DA3 DAC)
--
-- What this testbench checks:
--   1. The 16-bit word sent on the SPI bus is the expected one (dac_model)
--   2. The SCLK period is exactly 2-> 500 kHz (SCLK_check_process)
--   3. There are never more than 16 SCLK rising edges per frame

----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_pmod_da3 is
end tb_pmod_da3;

architecture behavior of tb_pmod_da3 is

    -- Clock period for 125 MHz (1 / 125 MHz = 8 ns)
    constant CLK_PERIOD : time := 8 ns;

    -- Inputs of the UUT (driven by the testbench)
    signal clk             : std_logic := '0';
    signal reset           : std_logic := '1';
    signal y_valid         : std_logic := '0';
    signal Signal_filtered : std_logic_vector(15 downto 0) := (others => '0');

    -- Outputs of the UUT (only observed by the testbench)
    signal da3_cs_n        : std_logic;
    signal da3_din         : std_logic;
    signal da3_ldac        : std_logic;
    signal da3_sclk        : std_logic;

    -- Signals used by the checkers
    signal expected_data   : std_logic_vector(15 downto 0) := (others => '0'); -- word the DAC should receive
    signal captured_data   : std_logic_vector(15 downto 0) := (others => '0'); -- word actually seen on the bus
    signal error_count     : integer := 0;      -- data errors, only written by dac_model
    signal flag_error_sclk : std_logic := '0';  -- goes to '1' on any SCLK error, only written by SCLK_check_process
                                                -- (one driver per signal, otherwise VHDL complains)

begin

    ------------------------------------------------------------------------------
    -- Unit Under Test
    ------------------------------------------------------------------------------
    uut: entity work.pmod_da3
        port map (
            clk             => clk,
            reset           => reset,
            y_valid         => y_valid,
            Signal_filtered => Signal_filtered,
            da3_cs_n        => da3_cs_n,
            da3_din         => da3_din,
            da3_ldac        => da3_ldac,
            da3_sclk        => da3_sclk
        );

    ------------------------------------------------------------------------------
    -- Clock generation: 125 MHz, runs forever
    ------------------------------------------------------------------------------
    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    ------------------------------------------------------------------------------
    -- SCLK checker
    -- This process only watches the bus, it never drives the UUT.
    -- Idea: on every SCLK rising edge, measure the time since the previous
    -- rising edge (now - t0) and compare it with the expected period.
    -- Expected period: the divider counts 0..124 = 125 clk cycles per half period,
    -- so 2 * 125 = 250 cycles = 250 * 8 ns = 2000 ns (500 kHz).
    ------------------------------------------------------------------------------
    SCLK_check_process : process(da3_sclk, da3_cs_n)
        -- Variables keep their value between two wake-ups of the process
        variable t0           : time    := 0 ns;  -- time of the previous SCLK rising edge
        variable counter_sclk : integer := 0;     -- SCLK rising edges seen in the current frame
                                                  -- (no range on purpose: we want a clean error
                                                  --  message, not a "value out of range" crash)
    begin
        -- Start of a frame (CS goes low): reset the edge counter
        if falling_edge(da3_cs_n) then
            counter_sclk := 0;
        end if;

        -- End of a frame (CS goes high): all SCLK edges should be done by now.
        -- In a correct frame the counter has been incremented 16 times, so it reads 16.
        -- Too many edges are already caught during the frame (the >= 16 check),
        -- so here we only look for missing ones.

        if rising_edge(da3_cs_n) then
            if counter_sclk < 16 then
                report "[SCLK] Missing edges: expected 16, counted "
                       & integer'image(counter_sclk) severity error;
                flag_error_sclk <= '1';
            end if;
        end if;
        
        -- Only look at SCLK while the DAC is selected, edges outside a frame are ignored
        if da3_cs_n = '0' and rising_edge(da3_sclk) then

            -- Check 1: SCLK period
            -- The first edge of a frame has no previous edge to compare with, so we skip it.
            -- Order matters: read t0 first, THEN overwrite it with the current time.
            if counter_sclk > 0 and (now - t0) /= 250 * CLK_PERIOD then
                report "[SCLK] Expected period 2000 ns, measured: "
                       & time'image(now - t0) severity error;
                flag_error_sclk <= '1';
            end if;
            t0 := now;  -- remember this edge for the next measurement

            -- Check 2: no more than 16 edges per frame
            -- The counter is read before being incremented, so it goes 0..15
            -- for the 16 valid edges; reaching 16 means a 17th edge showed up.
            if counter_sclk >= 16 then
                report "[SCLK] More than 16 edges in the frame" severity error;
                flag_error_sclk <= '1';
            end if;
            counter_sclk := counter_sclk + 1;

        end if;
    end process;

    ------------------------------------------------------------------------------
    -- Fake DAC: rebuilds the 16-bit word sent on the SPI bus
    ------------------------------------------------------------------------------
    dac_model : process(da3_sclk, da3_cs_n)
    begin
        -- Shift in one bit on each SCLK rising edge while the DAC is selected (MSB first)
        if rising_edge(da3_sclk) and da3_cs_n = '0' then
            captured_data <= captured_data(14 downto 0) & da3_din;
        end if;

        -- End of frame (CS rising edge): compare with the expected word
        if rising_edge(da3_cs_n) then
            if captured_data /= expected_data then
                error_count <= error_count + 1;
                report "[TB DA3] Wrong DAC word" severity error;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------------
    -- Stimulus: reset, send a few samples, then print the final verdict
    ------------------------------------------------------------------------------
    stim_proc: process

        -- Sends one sample to the UUT and waits for the SPI frame to finish
        procedure send_sample(
            constant data_in : in std_logic_vector(15 downto 0)
        ) is
        begin
            -- Change inputs on the falling edge so they are stable on the next rising edge
            wait until falling_edge(clk);

            -- The module flips the MSB (signed to offset binary), so the DAC
            -- should receive the input with bit 15 inverted
            expected_data   <= not(data_in(15)) & data_in(14 downto 0);
            Signal_filtered <= data_in;
            y_valid         <= '1';

            -- y_valid is a one-cycle pulse
            wait for CLK_PERIOD;
            y_valid <= '0';

            -- One frame is 16 bits * 2 us = 32 us, wait a bit more to be safe
            wait for 50 us;
        end procedure;

    begin
        -- Active-high reset
        reset <= '1';
        wait for 100 ns;
        wait for CLK_PERIOD * 2;

        -- Release reset and let the design settle
        reset <= '0';
        wait for CLK_PERIOD * 10;

        -- Test vectors: random pattern, small value, extremes and sign boundary
        send_sample(x"A5A5");
        send_sample(x"1234");
        send_sample(x"FFFF");  -- -1 in two's complement
        send_sample(x"0000");  -- zero
        send_sample(x"7FFF");  -- max positive
        send_sample(x"8000");  -- max negative

        -- Final verdict: looks at every checker, not just the data one
        if error_count = 0 and flag_error_sclk = '0' then
            report "*** TEST PASSED ***";
        else
            report "*** TEST FAILED: " & integer'image(error_count)
                   & " data error(s), SCLK error = "
                   & std_logic'image(flag_error_sclk) & " ***" severity failure;
        end if;

        wait;  -- stop this process for good
    end process;

end behavior;