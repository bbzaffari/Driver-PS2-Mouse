----------------------------------------------------------------------------------------    
 -- Nome: Bruno Bavaresco Zaffari
 -- Projetos de sistemas integrados 2
 -- Mouse ps2_driver_tb
----------------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_ps2_driver is
end entity;

architecture tb of tb_ps2_driver is
    -- sinais UUT
    signal clock_in_tb    : std_logic := '0';
    signal reset_in_tb    : std_logic := '1';
    signal ps2_clock_tb   : std_logic := '1';
    signal ps2_data_tb    : std_logic := '1';
    signal LR_tb          : std_logic_vector(1 downto 0);
    signal XV_tb, YV_tb, XS_tb, YS_tb : std_logic;
    signal X_tb, Y_tb       : std_logic_vector(7 downto 0);
    signal enable_tb    : std_logic;

	
	--------------------------------------------------------------------------
	constant TIMES : integer := 3;

	-- DATA_TO_SEND---------------------------------------------------------------
	constant BITS  : integer := 33;
	
	 -- bitstream 
	signal data_to_send: std_logic_vector(0 to 32) := (others => '0');
	
    constant START : std_logic := '0';
    constant STOP  : std_logic := '1';
	constant zero_one :std_logic_vector(0 to 1) := "10";
	
	-- Byte 0 = 0x11  +  parity=0
	signal LR_bit :std_logic_vector(0 to 1) := "11";
	signal XS_bit :std_logic := '0';
	signal YS_bit :std_logic := '0';
	signal XV_bit :std_logic := '0';
	signal YV_bit :std_logic := '0';
	
	signal control :std_logic_vector(0 to 7) := (others => '0');
	
	-- Byte[1] = 0x05 (0000 0101) +  parity=1
    signal X_byte :std_logic_vector(0 to 7) :=  "00000101";
	-- Byte[2] = 0x02 (0000 0010) +  parity=0
	signal Y_byte :std_logic_vector(0 to 7) :=  "00000010"; 

	signal x_p :std_logic;
    signal y_p :std_logic;
	signal c_p :std_logic;
	----------------------------------------------------------------
	signal ps2_reference :std_logic := '1';
	signal flag_ps2_clk :std_logic := '0';
	
	-------------------------------------------------------------------
	-- =================================DEBUG===============================================
	constant CR : string := character'val(13) & character'val(10); -- Carriage Return + Line Feed
	-- Para std_logic
	function to_str(bit : std_logic) return string is
	begin
		return std_ulogic'image(bit);
	end function;

	-- Para std_logic_vector
	function to_str(vec: std_logic_vector) return string is 
		variable s : string(1 to vec'length);
	begin
		for i in vec'range loop
			s(i - vec'low + 1) := std_ulogic'image(vec(i))(2);  -- extrai o caractere '0' ou '1'
		end loop;
		return s;
	end function;
	-- =================================DEBUG===============================================
	
	function xor_reduce(vec: std_logic_vector) return std_logic is -- Pariedade impar
		variable result : std_logic := '1';
	begin
		for i in vec'range loop
			result := result xor vec(i);
		end loop;
		return result;
	end function;

	-- function reverse_bits(input : std_logic_vector(7 downto 0)) return std_logic_vector is
		-- variable result : std_logic_vector(7 downto 0);
	-- begin
		-- for i in 0 to 7 loop
			-- result(i) := input(7 - i);
		-- end loop;
		-- return result;
	-- end function;
	
	function reverse_bits(input : std_logic_vector(0 to 7)) return std_logic_vector is
		variable result : std_logic_vector(0 to 7);
	begin
		for i in 0 to 7 loop
			result(i) := input(7 - i);
		end loop;
		return result;
	end function;
    -------------------------------------------------------------------
begin
    -- Instancia UUT
    UUT: entity work.ps2_mouse
        port map (
            clock_in  => clock_in_tb,
            reset_in  => reset_in_tb,
            ps2_clock => ps2_clock_tb,
            ps2_data  => ps2_data_tb,
            LR        => LR_tb,
            XV        => XV_tb,
            YV        => YV_tb,
            XS        => XS_tb,
            YS        => YS_tb,
            X         => X_tb,
            Y         => Y_tb,
            enable    => enable_tb
        );
	-------------------------------------------------------------------
    clock_in_tb <= not clock_in_tb after 5 ns;-- 100MHz

    ps2_reference <= not ps2_reference after 20 ns;-- 25kHz 
	
	ps2_clock_tb <= ps2_reference when flag_ps2_clk = '1' else '1';
	
	reset_in_tb <= '1', '0' after 10 ns;

    TX: process
    begin
		for TIME in 1 to TIMES loop
		
			ps2_data_tb <= '1';
			flag_ps2_clk <= '1';
			wait for 2 us;

			report "[TB TX] - SENDING N" & std_logic'image(START) & "#";
			-------------------------------------------------------------------
			-------------------- Montando bitstream ---------------------------
			-------------------------------------------------------------------
			control <= LR_bit & zero_one & XS_bit & YS_bit & XV_bit & YV_bit;
			
			x_p <= xor_reduce(x_byte);
			y_p <= xor_reduce(y_byte);
			c_p<= xor_reduce(control);
			
			data_to_send <= START&control&c_p&STOP &START&x_byte&x_p&STOP &START&y_byte&y_p&STOP;
			-------------------------------------------------------------------
			-------------------------------------------------------------------
			-- DEBUG
			report "[TB TX] - data_to_send = " & CR &
				   "  Byte 0: " & std_logic'image(START) & to_str(control) & std_logic'image(c_p) & std_logic'image(STOP) & CR &
				   "  Byte 1: " & std_logic'image(START) & to_str(x_byte) & std_logic'image(x_p) & std_logic'image(STOP) & CR &
				   "  Byte 2: " & std_logic'image(START) & to_str(y_byte) & std_logic'image(y_p) & std_logic'image(STOP);

			   
			report "=============================================================================================================="; 
			-------------------------------------------------------------------
			flag_ps2_clk <= '1';
			wait for 0 ns; -- EFEITO IMEDIATO
			
			
			for i in 0 to BITS-1 loop
				ps2_data_tb <= data_to_send(i);  -- coloque o dado ANTES
				report "[TB TX] - Bit enviado(" & integer'image(i) & ") = '" & std_ulogic'image(data_to_send(i)) & "'";
				wait until ps2_clock_tb = '1';  
				wait until ps2_clock_tb = '0';  -- o mouse vai ler aqui
			end loop;
			
			flag_ps2_clk <= '0';
			wait for 0 ns; -- EFEITO IMEDIATO
			-------------------------------------------------------------------
			-- DEBUG
			report "[TB TX] - Envio finalizado"; 
			
	
		end loop;
        
    end process TX;
	
	RX: process (enable_tb) is 
		variable result : std_logic_vector(0 to 7);
	begin
		if enable_tb = '1' then 
		--------------------------------------------------------
			assert LR_tb = LR_bit
				report "[TB RX] - Error LR (V):" & to_str(LR_tb) & " (X):" & to_str(LR_bit) severity warning;
			assert LR_tb /= LR_bit
				report "[TB RX] LR CORRETO";
			--------------------------------------------------------
			assert XS_tb = XS_bit
				report "[TB RX] - Error XS (V):" & to_str(XS_tb) & " (X):" & to_str(XS_bit) severity warning;
			assert XS_tb /= XS_bit
				report "[TB RX] XS CORRETO";	
			--------------------------------------------------------
			assert YS_tb = YS_bit
				report "[TB RX] - Error YS (V):" & to_str(YS_tb) & " (X):" & to_str(YS_bit) severity warning;
			assert YS_tb /= YS_bit
				report "[TB RX] YS CORRETO";	
			--------------------------------------------------------
			assert XV_tb = XV_bit
				report "[TB RX] - Error XV (V):" & to_str(XV_tb) & " (X):" & to_str(XV_bit) severity warning;
			assert XV_tb /= XV_bit
				report "[TB RX] XV CORRETO";	
			--------------------------------------------------------
			assert YV_tb = YV_bit
				report "[TB RX] - Error YV (V):" & to_str(YV_tb) & " (X):" & to_str(YV_bit) severity warning;
			assert YV_tb /= YV_bit
				report "[TB RX] YV CORRETO";	
			--------------------------------------------------------
			result := reverse_bits(X_byte);
			assert X_tb = result
				report "[TB RX] - Error X (V):" & to_str(X_tb) & " (X):" & to_str(X_byte) severity warning;
			assert X_tb /= X_byte
				report "[TB RX] X CORRETO";	
			--------------------------------------------------------
			assert Y_tb = reverse_bits(Y_byte)
				report "[TB RX] - Error Y (V):" & to_str(Y_tb) & " (X):" & to_str(Y_byte) severity warning;
			assert Y_tb /= Y_byte
				report "[TB RX] Y CORRETO";	
			assert false report "Fim da simulação." severity failure;
		end if;
		
	end process RX;
	
end architecture;
