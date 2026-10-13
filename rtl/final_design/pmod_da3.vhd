--------------------------------------------------------------------------------
-- Module      : pmod_da3
-- Description : CUSTOM SPI master for the Digilent Pmod DA3 (AD5541A, 16-bit DAC).
--               Sends one 16-bit frame per filtered sample (y_valid pulse).
--               SPI mode 0: the DAC samples DIN on the SCLK rising edge,
--               DIN is updated after the SCLK falling edge.
--               SCLK = 500 kHz (125 MHz / 250), generated in the clk domain.
--               LDAC is tied low: the DAC output updates on the CS rising edge.
-- Note        : y_valid is only checked in IDLE. A sample arriving during a
--               frame would be dropped; this cannot happen in normal operation
--               (frame = 32 us << sample period = 208 us at 4.8 kHz).
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pmod_da3 is
    Port (
           clk             : in  STD_LOGIC;                      -- 125 MHz system clock
           RESET           : in  STD_LOGIC;                      -- synchronous reset, active HIGH
           y_valid         : in  STD_LOGIC;                      -- one-cycle pulse: new sample available
           Signal_filtered : in  STD_LOGIC_VECTOR (15 downto 0); -- filtered sample, signed Q15
           da3_cs_n        : out STD_LOGIC;                      -- chip select, active low
           da3_din         : out STD_LOGIC;                      -- serial data, MSB first
           da3_ldac        : out STD_LOGIC;                      -- load DAC, tied low
           da3_sclk        : out STD_LOGIC                       -- serial clock, 500 kHz
           );
end pmod_da3;
 

architecture Behavioral of pmod_da3 is
    type state_type is (IDLE, TRANSMISSION, END_TRANSMISSION);
    signal state: state_type;
    signal div_count : integer range 0 to 124 := 0; -- For SCLK Frequency 125 Mhz => 500 Khz
    signal counter_16 : integer range 0 to 16 := 0;   ---- bit counter: 0 to 15 = bits sent, 16 = frame done
    signal shift_reg : STD_LOGIC_VECTOR(15 downto 0); --registre de 16 bits, l'échantillon capturé, avec le MSB inversé pour passer en binaire décalé.

begin

da3_ldac <= '0'; -- Maintenue niveau bas

    main_process: process(clk)
    variable sclk_v : std_logic := '0';
    begin
        if rising_edge(clk) then
            if RESET = '1' then
               da3_cs_n   <= '1';       -- DAC not selected
               da3_sclk   <= '0';       
               da3_din    <= '0';       
               sclk_v     := '0';       
               div_count  <= 0;         
               counter_16 <= 0;        
               state      <= IDLE;      
                
            else
                case state is
                    WHEN IDLE =>
                    -- Wait for a new sample, keep the bus idle
                        if y_valid = '0' then
                            da3_cs_n <= '1';
                            da3_sclk <= '0';
                            da3_din <= '0';
                            sclk_v := '0';
                            div_count <= 0; 
                            counter_16 <= 0;
                            
                        else
                        -- New sample: capture it and convert signed Q15 to offset binary
                            shift_reg <= (not Signal_filtered(15)) & Signal_filtered(14 downto 0);
                            state <= TRANSMISSION;
                        end if;

                    WHEN TRANSMISSION =>
                        if counter_16 <= 15 then
                            if div_count < 124 then
                            -- Select the DAC and present the current bit, MSB first
                                da3_cs_n <= '0';
                                da3_din <= shift_reg(15 - counter_16);  --on envoie un bit a chaque fois 
                                div_count <= div_count+1;       
                            else
                                -- End of a half-period: toggle SCLK
                                sclk_v := not sclk_v;
                                da3_sclk <= sclk_v;
                                div_count <= 0;
                                if sclk_v = '0' then -- DATA SENT on LOW LEVEL OF SCLK !
                                -- Falling edge: the DAC has read the bit, move to the next one
                                    counter_16 <= counter_16+1;    
                                end if;  
                            end if;
                        
                        else
                            state <= END_TRANSMISSION;
                            counter_16 <= 0;    
                            div_count <= 0;  
                        end if;
                    
                    WHEN END_TRANSMISSION =>
                    -- CS rising edge: the DAC loads the new code (LDAC low)
                            da3_cs_n <= '1';
                            da3_sclk <= '0';
                            state <= IDLE; 
                                       
                end case;
            end if;
        end if;
    end process;
 
end Behavioral;
