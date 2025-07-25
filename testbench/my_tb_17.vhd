-- due sequenze sugli stessi indirizzi di memoria
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
entity project_tb is
end project_tb;
architecture project_tb_arch of project_tb is    
    constant CLOCK_PERIOD : time := 20 ns;    
    signal tb_clk : std_logic := '0';    
    signal tb_rst, tb_start, tb_done : std_logic;    
    signal tb_add : std_logic_vector(15 downto 0);    
    signal tb_k   : std_logic_vector(9 downto 0);
    signal tb_o_mem_addr, exc_o_mem_addr, init_o_mem_addr : std_logic_vector(15 downto 0);    
    signal tb_o_mem_data, exc_o_mem_data, init_o_mem_data : std_logic_vector(7 downto 0);    
    signal tb_i_mem_data : std_logic_vector(7 downto 0);    
    signal tb_o_mem_we, tb_o_mem_en, exc_o_mem_we, exc_o_mem_en, init_o_mem_we, init_o_mem_en : std_logic;
    type ram_type is array (65535 downto 0) of std_logic_vector(7 downto 0);    
    signal RAM : ram_type := (OTHERS => "00000000");
    constant SCENARIO_LENGTH : integer := 14;    
    type scenario_type_1 is array (0 to SCENARIO_LENGTH*2-1) of integer;    
    signal scenario_input : scenario_type_1 := (128, 0,  64, 0,   0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 100,  0, 1,  0, 0,  0, 5,  0, 23,  0, 200,  0,   0,  0 );    
    signal scenario_full  : scenario_type_1 := (128, 31, 64, 31, 64, 30, 64, 29, 64, 28, 64, 27, 64, 26, 100, 31, 1, 31, 1, 30, 5, 31, 23, 31, 200, 31, 200, 30 );    
    constant SCENARIO_ADDRESS : integer := 1000;
    signal scenario_full_2: scenario_type_1 := (128, 31, 64, 31, 64, 31, 64, 31, 64, 31, 64, 31, 64, 31, 100, 31, 1, 31, 1, 31, 5, 31, 23, 31, 200, 31, 200, 31 );           
    signal memory_control : std_logic := '0';        
    component project_reti_logiche is        
        port (                
            i_clk : in std_logic;                
            i_rst : in std_logic;                
            i_start : in std_logic;                
            i_add : in std_logic_vector(15 downto 0);                
            i_k   : in std_logic_vector(9 downto 0);                                
            o_done : out std_logic;                                
            o_mem_addr : out std_logic_vector(15 downto 0);                
            i_mem_data : in  std_logic_vector(7 downto 0);                
            o_mem_data : out std_logic_vector(7 downto 0);                
            o_mem_we   : out std_logic;                
            o_mem_en   : out std_logic        
        );    
    end component project_reti_logiche;
begin    

    UUT : project_reti_logiche    
    port map(                
        i_clk   => tb_clk,                
        i_rst   => tb_rst,                
        i_start => tb_start,                
        i_add   => tb_add,                
        i_k     => tb_k,                                
        o_done => tb_done,                                
        o_mem_addr => exc_o_mem_addr,                
        i_mem_data => tb_i_mem_data,                
        o_mem_data => exc_o_mem_data,                
        o_mem_we   => exc_o_mem_we,                
        o_mem_en   => exc_o_mem_en    
    );

    -- Clock generation    
    tb_clk <= not tb_clk after CLOCK_PERIOD/2;

    -- Process related to the memory    
    MEM : process (tb_clk)    
    begin        
        if tb_clk'event and tb_clk = '1' then            
            if tb_o_mem_en = '1' then                
                if tb_o_mem_we = '1' then                    
                    RAM(to_integer(unsigned(tb_o_mem_addr))) <= tb_o_mem_data after 1 ns;                    
                    tb_i_mem_data <= tb_o_mem_data after 1 ns;                
                else                    
                    tb_i_mem_data <= RAM(to_integer(unsigned(tb_o_mem_addr))) after 1 ns;                
                end if;            
            end if;        
        end if;    
    end process;        

    memory_signal_swapper : process(memory_control, init_o_mem_addr, init_o_mem_data,                                    
        init_o_mem_en,  init_o_mem_we,   exc_o_mem_addr,                                    
        exc_o_mem_data, exc_o_mem_en, exc_o_mem_we)    
    begin        
        -- This is necessary for the testbench to work: we swap the memory        
        -- signals from the component to the testbench when needed.            
        tb_o_mem_addr <= init_o_mem_addr;        
        tb_o_mem_data <= init_o_mem_data;        
        tb_o_mem_en   <= init_o_mem_en;        
        tb_o_mem_we   <= init_o_mem_we;
        if memory_control = '1' then            
            tb_o_mem_addr <= exc_o_mem_addr;            
            tb_o_mem_data <= exc_o_mem_data;            
            tb_o_mem_en   <= exc_o_mem_en;            
            tb_o_mem_we   <= exc_o_mem_we;        
        end if;    
    end process;        

    -- This process provides the correct scenario on the signal controlled by the TB    
    create_scenario : process    
    begin        
        wait for 50 ns;
        -- Signal initialization and reset of the component        
        tb_start <= '0';        
        tb_add <= (others=>'0');        
        tb_k   <= (others=>'0');        
        tb_rst <= '1';                
        -- Wait some time for the component to reset...        
        wait for 50 ns;               

        -----------------------------------------------        
        -- FIRST SEQUENCE        
        -----------------------------------------------
        tb_rst <= '0';        
        memory_control <= '0';  -- Memory controlled by the testbench                
        wait until falling_edge(tb_clk); 

        -- Skew the testbench transitions with respect to the clock
        -- Configure the memory                
        for i in 0 to SCENARIO_LENGTH*2-1 loop            
            init_o_mem_addr<= std_logic_vector(to_unsigned(SCENARIO_ADDRESS+i, 16));            
            init_o_mem_data<= std_logic_vector(to_unsigned(scenario_input(i),8));            
            init_o_mem_en  <= '1';            
            init_o_mem_we  <= '1';            
            wait until rising_edge(tb_clk);           
        end loop;                

        wait until falling_edge(tb_clk);
        memory_control <= '1';  -- Memory controlled by the component                
        tb_add <= std_logic_vector(to_unsigned(SCENARIO_ADDRESS, 16));        
        tb_k   <= std_logic_vector(to_unsigned(SCENARIO_LENGTH, 10));                
        tb_start <= '1';
        
        while tb_done /= '1' loop                            
            wait until rising_edge(tb_clk);        
        end loop;
        
        wait for 5 ns;                
        tb_start <= '0';        
        wait for 5 ns;
        
        -----------------------------------------------        
        -- SECOND SEQUENCE        
        -----------------------------------------------                
        wait until falling_edge(tb_clk);        
        memory_control <= '1';  -- Memory controlled by the component        
        tb_add <= std_logic_vector(to_unsigned(SCENARIO_ADDRESS, 16));        
        tb_k   <= std_logic_vector(to_unsigned(SCENARIO_LENGTH, 10));        
        wait for 0 ns;                

        tb_start <= '1';
        
        while tb_done /= '1' loop                            
            wait until rising_edge(tb_clk);        
        end loop;
        
        wait for 5 ns;                
        tb_start <= '0';        
        wait for 0 ns;                
        wait;            
    end process;

    -- Process without sensitivity list designed to test the actual component.    
    test_routine : process    begin
        wait until tb_rst = '1';        
        wait for 25 ns;        
        assert tb_done = '0' report "TEST FALLITO o_done !=0 during reset" severity failure;        
        wait until tb_rst = '0';
        wait until falling_edge(tb_clk);        
        assert tb_done = '0' report "TEST FALLITO o_done !=0 after reset before start" severity failure;                

        -----------------------------------------------        
        -- FIRST SEQUENCE        
        -----------------------------------------------
        wait until rising_edge(tb_start);
        while tb_done /= '1' loop                            
            wait until rising_edge(tb_clk);        
        end loop;
        assert tb_o_mem_en = '0' or tb_o_mem_we = '0' report "TEST FALLITO o_mem_en !=0 memory should not be written after done." severity failure;
        for i in 0 to SCENARIO_LENGTH*2-1 loop            
            assert RAM(SCENARIO_ADDRESS+i) = std_logic_vector(to_unsigned(scenario_full(i),8)) report "TEST FALLITO @ OFFSET=" & integer'image(i) & " expected= " & integer'image(scenario_full(i)) & " actual=" & integer'image(to_integer(unsigned(RAM(i)))) severity failure;        
        end loop;
        wait until falling_edge(tb_start);        
        assert tb_done = '1' report "TEST FALLITO o_done !=0 after reset before start" severity failure;        
        wait until falling_edge(tb_done);
        assert false report "Simulation Ended! TEST 1 PASSATO (EXAMPLE)";
        
        -----------------------------------------------        
        -- SECOND SEQUENCE        
        -----------------------------------------------
        wait until rising_edge(tb_start);
        while tb_done /= '1' loop                            
            wait until rising_edge(tb_clk);        
        end loop;
        assert tb_o_mem_en = '0' or tb_o_mem_we = '0' report "TEST FALLITO o_mem_en !=0 memory should not be written after done." severity failure;
        for i in 0 to SCENARIO_LENGTH*2-1 loop            
            assert RAM(SCENARIO_ADDRESS+i) = std_logic_vector(to_unsigned(scenario_full_2(i),8)) report "TEST FALLITO @ OFFSET=" & integer'image(i) & " expected= " & integer'image(scenario_full_2(i)) & " actual=" & integer'image(to_integer(unsigned(RAM(i)))) severity failure;        
        end loop;
        wait until falling_edge(tb_start);        
        assert tb_done = '1' report "TEST FALLITO o_done !=0 after reset before start" severity failure;        
        wait until falling_edge(tb_done);
        assert false report "Simulation Ended! TEST 2 PASSATO (EXAMPLE)" severity failure;    
    end process;
end architecture;