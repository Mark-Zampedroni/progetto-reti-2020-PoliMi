library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity project_reti_logiche is
    Port ( 
        i_clk     : in std_logic;
        i_start   : in std_logic;
        i_rst     : in std_logic;
        i_data    : in std_logic_vector(7 downto 0);
        o_address : out std_logic_vector(15 downto 0);
        o_done    : out std_logic;
        o_en      : out std_logic;
        o_we      : out std_logic;
        o_data    : out std_logic_vector(7 downto 0)
    );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
	--fsm--    
    type state_name is (IDLE, CHECK, DONE);
    signal STATE, STATE_NEXT : state_name := IDLE;
	signal o_done_next, o_we_next : std_logic := '0';
	signal o_data_next : std_logic_vector(7 downto 0) := "00000000";
	signal got_uncoded, got_uncoded_next : boolean := false;
	signal uncoded_addr, uncoded_addr_next : std_logic_vector(6 downto 0) := "0000000";
	-- loader --
    constant BASE : std_logic_vector(11 downto 0) := "000000000000";
	signal index : std_logic_vector(3 downto 0) := "1000";
	signal loaded_all : boolean := false;
	signal got_encoded : std_logic := '0';
	
begin
    -- Contatore sequenziale, il resto è combinatorio --
    process (i_clk, i_rst, i_start, o_we_next) 
    begin
        if(i_rst = '1' or i_start = '0') then
            index <= "1000";
            o_en <= '0';
            loaded_all <= false;
            got_encoded <= '0';
        elsif(i_clk'event and i_clk = '1') then
            if(o_we_next = '1') then 
                o_address <= BASE & "1001";  
                got_encoded <= '1';
            elsif(i_start = '1') then
                o_en <= not(got_encoded);
                o_address <= BASE & index;  
                index <= index - "1";     
                if(index = "1111") then
                    loaded_all <= true;
                end if;           
            end if;
        end if;       
    end process;
    -- Logica dei registri FSM, sequenziale --
    process (i_clk, i_rst) 
    begin
        if (i_rst = '1') then
            o_done <= '0';
            o_we <= '0';
            got_uncoded <= false; 
			STATE <= IDLE;
			
        elsif (i_clk'event and i_clk='1') then
            o_done <= o_done_next;
            o_data <= o_data_next;
            o_we <= o_we_next; 
            got_uncoded <= got_uncoded_next; 
			uncoded_addr <= uncoded_addr_next;            
            STATE <= STATE_NEXT;
        end if;
    end process;
    -- Logica degli stati FSM, combinatorio --
    process(STATE, i_start, i_data, uncoded_addr, got_uncoded, index, loaded_all)
        variable encod_index : std_logic_vector(3 downto 0) := "0000";
        variable offset : integer range 0 to 255 := 0; --- conversione da std_logic_vector di 8 bit a max 255 
    begin
        o_done_next <= '0';
        o_data_next <= "00000000"; -- serve per la corretta codifica dell' onehot
        o_we_next <= '0';
        
		uncoded_addr_next <= uncoded_addr;
		got_uncoded_next <= got_uncoded;
		
		STATE_NEXT <= STATE;
		
        case STATE is
            when IDLE =>
                if(index(0) = '1') then --- il load ha fatto la prima richiesta
                    STATE_NEXT <= CHECK;
                end if;
            when CHECK =>
                if(not got_uncoded) then 
                    uncoded_addr_next <= i_data(6 downto 0);
                    got_uncoded_next <= true; 
                else
                    encod_index := index + "10"; -- l'index della WZ in arrivo su i_data e' quello di 2 cicli di clk fa   
                    -- sottrazione ad 8 bit supponendo che le WZ arrivino fino a 127, con certezza siano complete e arrivino fino a 124 si può abbassare a 7 bit
                    offset := to_integer(unsigned("0" & (uncoded_addr) - i_data)); -- Differenza tra indirizzo da codificare e indirizzo WZ, gioca su effetto pac-man                    
                    if(offset < 4) then -- Se WZ trovata
                        o_data_next(7 downto 4) <= "1" & encod_index(2 downto 0); -- qui (3 downto 0) sara' sempre "0000"
                        o_data_next(offset) <= '1';
                        o_we_next <= '1'; 
                        STATE_NEXT <= DONE;                    
                    elsif(loaded_all) then -- Se nessuna WZ trovata
                        o_data_next <= "0" & uncoded_addr;
                        o_we_next <= '1';
                        STATE_NEXT <= DONE;
                    end if;
                end if;
				
            when DONE =>
                if (i_start = '0') then
                    got_uncoded_next <= false; 
                    STATE_NEXT <= IDLE;
                else
                    o_done_next <= '1';
                end if;
        end case;
    end process;          
end Behavioral;
