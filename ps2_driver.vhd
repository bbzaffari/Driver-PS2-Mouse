--------------------------------------------------------------------------------------------    
--  Nome: Bruno Bavaresco Zaffari
--  Projetos de sistemas integrados 2
--  Mouse ps2_driver 
--------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;

entity ps2_mouse is
	generic(
		DEBUG : std_logic := '1'
	);
    Port (
        clock_in   : in  std_logic;
        reset_in   : in  std_logic;
        ps2_clock  : in  std_logic;
        ps2_data   : in  std_logic;
        LR         : out std_logic_vector(1 downto 0);
        XV         : out std_logic;
        YV         : out std_logic;
        XS         : out std_logic;
        YS         : out std_logic;
        X          : out std_logic_vector(7 downto 0);
        Y          : out std_logic_vector(7 downto 0);
        enable     : out std_logic
    );
end ps2_mouse;

architecture rtl of ps2_mouse is

    type STATES is (IDLE, RECEIVING, ERROR, SEND, DONE);
    signal STATE : STATES := IDLE;

    signal bit_count : integer range 0 to 10 := 0;     -- 11 bits
    signal byte_count : integer range 0 to 2 := 0;     -- 03 bits
    signal frame : std_logic_vector(7 downto 0);       -- 08 bits
    signal ps2_clock_sync : std_logic_vector(2 downto 0);
	signal count_ones : integer range 0 to 8 := 0;
	
	signal count_ERROR : integer range 0 to 33 := 0; -- 
	
	
	signal LR_int : std_logic_vector(1 downto 0);
	signal XV_int, YV_int, XS_int, YS_int : std_logic;
	signal X_int, Y_int : std_logic_vector(7 downto 0);

	
	--=================================DEBUG===============================================
	-- constant CR : string := character'val(13) & character'val(10); -- Carriage Return + Line Feed

	-- function to_str(bit : std_logic) return string is
	-- begin
		-- return std_ulogic'image(bit);
	-- end function;
	
	-- function to_str(vec: std_logic_vector) return string is
		-- variable s : string(1 to vec'length);
	-- begin
		-- for i in vec'range loop
			-- s(i - vec'low + 1) := std_ulogic'image(vec(i))(2);
		-- end loop;
		-- return s;
	-- end function;
	--=================================DEBUG===============================================

begin
	
	LR <= LR_int;
	XV <= XV_int;
	YV <= YV_int;
	XS <= XS_int;
	YS <= YS_int;
	X  <= X_int;
	Y  <= Y_int;

    process(clock_in)
    begin
        if rising_edge(clock_in) then
            if reset_in = '1' then
				STATE <= IDLE;
				bit_count <= 0;
				byte_count <= 0;
				enable <= '0';
				count_ones <= 0;
				frame <= (others => '0');
				ps2_clock_sync <= (others => '0');
				count_ERROR <= 0;
				X_int  <= (others => '0');
				Y_int  <= (others => '0');
            else
				ps2_clock_sync <= ps2_clock_sync(1 downto 0) & ps2_clock;
                if ps2_clock_sync(2 downto 1) = "10" then  -- borda de descida
					--report "[DRIVER] Borda de descida detectada, estado: " & STATES'IMAGE(STATE);
					case STATE is
						when IDLE =>
							if ps2_data = '0' then -- detecta e descarta start bit
								-- report "[DRIVER] START BIT detectado, transição para RECEIVING";
								frame <= (others => '0');
								STATE <= RECEIVING;
								count_ones <= 0;
								bit_count <= 0;
							end if;

						when RECEIVING =>
							if ((bit_count = 9) and (ps2_data = '1'))then -- stop bit			
								-- report "[DRIVER] STOP bit correto recebido. byte_count = " & integer'image(byte_count);
								
								-- report "======================================================= " & 
								-- CR & "[DRIVER] BYTE " & integer'image(byte_count) & " END" & 
								-- CR & to_str(frame(7 downto 0)) & 
								-- CR &" ======================================================= " ;
									
								count_ones <= 0;
								bit_count <= 0;
								
								if byte_count = 0 then
									LR_int <= frame(1 downto 0);
									XS_int <= frame(4);
									YS_int <= frame(5);
									XV_int <= frame(6);
									YV_int <= frame(7);
									byte_count <= byte_count + 1;
									STATE <= IDLE;
									
								elsif byte_count = 1 then
									X_int(7 downto 0)  <= frame(7 downto 0);
									byte_count <= byte_count + 1;
									STATE <= IDLE;
								
								elsif byte_count = 2 then -- se pegou 3 bytes manda
									Y_int(7 downto 0)  <= frame(7 downto 0);
									
									byte_count <= 0;
									STATE <= SEND;
									--=================================DEBUG===============================================
									-- if DEBUG = '1' then										   
										-- report "[DRIVER] FRAME COMPLETO RECEBIDO:" & 
												-- CR & "> Byte 0 (Controle) : " &
												-- CR & " LR = " & to_str(LR_int)&
												-- CR & " 10 = 10" &
												-- CR & " XS = " & to_str(XS_int) &
												-- CR & " YS = " & to_str(YS_int) &
												-- CR & " XV = " & to_str(XV_int) &
												-- CR & " YV = " & to_str(YV_int) & 
												-- CR & "> Byte 1 (X) : " & to_str(X_int) &
												-- CR & "> Byte 2 (Y) : " & to_str(frame(7 downto 0)) & CR ;			
									-- end if;
									--====================================================================================
								end if;
								
							elsif bit_count = 8 then -- bit pariedade
								-- report "[DRIVER] Bit de paridade recebido = '" & std_ulogic'image(ps2_data) & "'";
								-- report "[DRIVER] Quantidade de bits 1 (count_ones) = " & integer'image(count_ones mod 2);
								bit_count <= bit_count + 1;
								if(((ps2_data = '1') and ((count_ones mod 2) = 1)) or ((ps2_data = '0') and ((count_ones mod 2) = 0)) ) then
									-- report "[DRIVER] ERRO de paridade! delay calculado = '" & integer'image(byte_count * 9) & "'";
									STATE <= ERROR;
									count_ERROR <= (byte_count*9);
								end if;		
								
							elsif bit_count < 8 then -- "7 a 0"
								-- 7 ate 0 
								-- 15 ate 8
								-- 23 ate 16
								frame(bit_count) <= ps2_data;
								-- report "[DRIVER] Bit recebido (" & integer'image(bit_count) & ") = '" & std_ulogic'image(ps2_data) & "'";
								bit_count <= bit_count + 1;
								if ps2_data = '1' then
									count_ones <= count_ones +1;
								end if;
							end if;
							
						when ERROR =>
							-- report "[DRIVER] ERRO de paridade no byte " & integer'image(byte_count);

							if count_ERROR = 32 then
								STATE <= IDLE;
							else
								count_ERROR <= count_ERROR + 1;
							end if;
					
						when SEND => -- stop bit
							-- report "[DRIVER] SEND - preparando saída, enable = '1'";
							enable <= '1';
							-- report "[DRIVER] SEND - COMPLETO RECEBIDO:" & 
									-- CR & "> Byte 0 (Controle) : " &
									-- CR & " LR = " & to_str(LR_int)&
									-- CR & " 10 = 10" &
									-- CR & " XS = " & to_str(XS_int) &
									-- CR & " YS = " & to_str(YS_int) &
									-- CR & " XV = " & to_str(XV_int) &
									-- CR & " YV = " & to_str(YV_int) & 
									-- CR & "> Byte 1 (X) : " & to_str(X_int) &
									-- CR & "> Byte 2 (Y) : " & to_str(Y_int) & CR ;
							STATE <= DONE;
							
						when DONE =>   
							enable <= '0';							
							STATE <= IDLE;	
							frame <= (others=>'0');
					end case;
				end if;
            end if;
        end if;
    end process;

end rtl;
