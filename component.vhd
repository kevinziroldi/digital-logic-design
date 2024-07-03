-------------------------------------
-- COUNTER 
-------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.all;

entity counter is 
    port(
        increment_count : in std_logic;
        clk, rst : in std_logic;
        curr_count : out std_logic_vector(9 downto 0)
    );
end counter;

architecture counter_arch of counter is
    signal count_value : unsigned(9 downto 0);
begin
    process(rst, clk)
    begin
        if rst = '1' then
            count_value <= (others => '0');
        elsif rising_edge(clk) and increment_count = '1' then
            count_value <= count_value + 1;
        end if;
    end process;
    curr_count <= std_logic_vector(count_value);
end counter_arch;

-------------------------------------
-- REGISTER 
-------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

entity register_8bit is 
    port(
        clk, rst : in std_logic;
        en_register : in std_logic;
        new_value : in std_logic_vector(7 downto 0);
        saved_value : out std_logic_vector(7 downto 0)
    );
end register_8bit;

architecture register_arch of register_8bit is
begin
    process(clk, rst)
    begin
        if rst = '1' then 
            saved_value <= (others => '0');
        elsif rising_edge(clk) and en_register = '1' then
            saved_value <= new_value;
        end if;
    end process;
end register_arch;

-------------------------------------
-- FF 
-------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.all;

entity ff_d is
    port(
      input : in std_logic;
      clk, rst : in std_logic;
      output : out std_logic;
      en_ff : in std_logic
    );
end ff_d;

architecture ff_d_arch of ff_d is
begin
    process(clk, rst)
    begin
        if rst = '1' then 
            output <= '0';
        elsif rising_edge(clk) and en_ff = '1' then 
            output <= input;
        end if;
        end process;
end ff_d_arch;

-------------------------------------
-- FSM 
-------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.all;

entity fsm is 
    port(
        i_clk, i_rst, i_start : in std_logic;
        i_add : in std_logic_vector(15 downto 0);
        i_k : in std_logic_vector(9 downto 0);
        o_done : out std_logic; 
        
        o_mem_addr : out std_logic_vector(15 downto 0);
        i_mem_data : in std_logic_vector(7 downto 0);
        o_mem_data : out std_logic_vector(7 downto 0);
        o_mem_we : out std_logic;
        o_mem_en : out std_logic;

        rst_reg : out std_logic;

        last_word : in std_logic_vector(7 downto 0);
        en_word_r : out std_logic;
        w_to_save : out std_logic_vector(7 downto 0);

        last_credibility : in std_logic_vector(7 downto 0);
        en_cred_r : out std_logic;
        c_to_save : out std_logic_vector(7 downto 0);

        increment_count : out std_logic;
        curr_count : in std_logic_vector(9 downto 0);

        set_zero : out std_logic;
        get_zero: in std_logic;
        en_ff : out std_logic
    );
end fsm;

architecture fsm_arch of fsm is
    type state_type is (START, INIT, CHECK_K, WAIT_INCREMENT, READ_W, WAIT_DATA, UPDATE_W, UPDATE_C, DONE_UP, DONE_DOWN);
    signal next_state, current_state: state_type;
begin
    state_reg: process(i_clk, i_rst)
    begin 
        if i_rst = '1' then
            current_state <= START;
        elsif rising_edge(i_clk) then
            current_state <= next_state;
        end if;
    end process;

    lambda_delta: process(current_state, i_start)
    begin
        increment_count <= '0';
        case current_state is 
            when START =>
                if i_start = '1' then 
                    next_state <= INIT;
                else 
                    next_state <= START;
                end if;
                o_done <= '0';
            when INIT =>
                next_state <= CHECK_K;
                o_done <= '0';
            when CHECK_K =>
                increment_count <= '1';
                if curr_count < i_k then 
                    next_state <= WAIT_INCREMENT;
                else
                    next_state <= DONE_UP;
                end if;
                o_done <= '0';
            when WAIT_INCREMENT =>
                next_state <= READ_W;
                o_done <= '0';
            when READ_W =>
                next_state <= WAIT_DATA;
                o_done <= '0';
            when WAIT_DATA =>
                next_state <= UPDATE_W;
                o_done <= '0';
            when UPDATE_W =>
                next_state <= UPDATE_C;
                o_done <= '0';
            when UPDATE_C =>
                next_state <= CHECK_K;
                o_done <= '0';
            when DONE_UP =>
                if i_start = '0' then 
                    next_state <= DONE_DOWN;
                else
                    next_state <= DONE_UP;
                end if;
                o_done <= '1';
            when DONE_DOWN =>
                if i_start = '0' then 
                    next_state <= DONE_DOWN;
                else
                    next_state <= INIT;
                end if;
                o_done <= '0';
            when others =>
                o_done <= '0';
                next_state <= START;
            end case;
    end process;

    elaboration : process(current_state)
        variable decremented_credibility : std_logic_vector(7 downto 0);
    begin
        rst_reg <= '0';
        o_mem_addr <= (others => '0');
        o_mem_en <= '0';
        o_mem_we <= '0';
        o_mem_data <= (others => '0');
        en_word_r <= '0';
        w_to_save <= (others => '0');
        en_cred_r <= '0';
        c_to_save <= (others => '0');
        en_ff <= '0';
        set_zero <= '0';

        case current_state is 

            when INIT => 
                rst_reg <= '1';
            
            when READ_W =>
                o_mem_addr <=   std_logic_vector( 
                                    unsigned(i_add) +
                                    unsigned("00000" & curr_count & '0') - 2
                                );
                o_mem_en <= '1';
                o_mem_we <= '0';
                
            when UPDATE_W =>
                if i_mem_data = "00000000" and last_word /= "00000000" then 
                    o_mem_en <= '1';
                    o_mem_we <= '1';
                    o_mem_addr <=   std_logic_vector( 
                                        unsigned(i_add) +
                                        unsigned("00000" & curr_count & '0') - 2
                                    );
                    o_mem_data <= last_word;
                elsif i_mem_data /= "00000000" then
                    en_word_r <= '1';
                    w_to_save <= i_mem_data;
                    
                end if;

                if i_mem_data = "00000000" then 
                    en_ff <= '1';
                    set_zero <= '1';
                else 
                    en_ff <= '1';
                    set_zero <= '0';
                end if;

            when UPDATE_C =>    
                o_mem_en <= '1';
                o_mem_we <= '1';
                o_mem_addr <=   std_logic_vector( 
                                    unsigned(i_add) +
                                    unsigned("00000" & curr_count & '0') - 1
                                );
                en_cred_r <= '0';
                c_to_save <= "00000000";
                
                if get_zero = '0' then 
                    o_mem_data <= "00011111";
                    en_cred_r <= '1';
                    c_to_save <= "00011111";
                else
                    if last_credibility = "00000000" then 
                        o_mem_data <= "00000000";
                    else
                        decremented_credibility := std_logic_vector(unsigned(last_credibility) - 1);
                        o_mem_data <= decremented_credibility;
                        en_cred_r <= '1';
                        c_to_save <= decremented_credibility;
                    end if;
                end if;

            when others => -- nulla
        end case;

    end process;

end fsm_arch;

-------------------------------------
-- PROJECT_RETI_LOGICHE (main entity)
-------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.all;

entity project_reti_logiche is
    port (
        i_clk   : in std_logic;
        i_rst : in std_logic;
        i_start : in std_logic;
        i_add   : in std_logic_vector(15 downto 0);
        i_k     : in std_logic_vector(9 downto 0);

        o_done  : out std_logic;

        o_mem_addr : out std_logic_vector(15 downto 0);
        i_mem_data : in std_logic_vector(7 downto 0);
        o_mem_data : out std_logic_vector(7 downto 0);
        o_mem_we   : out std_logic;
        o_mem_en   : out std_logic
    );
end project_reti_logiche;

architecture project_reti_logiche_arch of project_reti_logiche is
    
    -- SIGNALS
    signal rst_reg : std_logic; -- rst_reg per fsm, rst per registri e counter
    
    -- word register
    signal last_word : std_logic_vector(7 downto 0); 
    signal en_word_r : std_logic; 
    signal w_to_save : std_logic_vector(7 downto 0); 

    -- credibility register
    signal last_credibility : std_logic_vector(7 downto 0); 
    signal en_cred_r : std_logic; 
    signal c_to_save : std_logic_vector(7 downto 0); 

    -- counter 
    signal curr_count : std_logic_vector(9 downto 0); 
    signal increment_count : std_logic; 

    -- ff
    signal set_zero : std_logic;
    signal get_zero : std_logic;
    signal en_ff : std_logic;

    -- COMPONENTS
    component counter is 
        port(
            increment_count : in std_logic;
            clk, rst : in std_logic;
            curr_count : out std_logic_vector(9 downto 0)
        );
    end component;

    component register_8bit is 
        port(
            clk, rst : in std_logic;
            en_register : in std_logic;
            new_value : in std_logic_vector(7 downto 0);
            saved_value : out std_logic_vector(7 downto 0)
        );
    end component;

    component ff_d is 
        port(
            input : in std_logic;
            clk, rst : in std_logic;
            output : out std_logic;
            en_ff : in std_logic
        );
    end component;

    component fsm is 
        port(
            i_clk, i_rst, i_start : in std_logic;
            i_add : in std_logic_vector(15 downto 0);
            i_k : in std_logic_vector(9 downto 0);
            o_done : out std_logic; 
            
            o_mem_addr : out std_logic_vector(15 downto 0);
            i_mem_data : in std_logic_vector(7 downto 0);
            o_mem_data : out std_logic_vector(7 downto 0);
            o_mem_we : out std_logic;
            o_mem_en : out std_logic;
    
            rst_reg : out std_logic;
    
            last_word : in std_logic_vector(7 downto 0);
            en_word_r : out std_logic;
            w_to_save : out std_logic_vector(7 downto 0);
    
            last_credibility : in std_logic_vector(7 downto 0);
            en_cred_r : out std_logic;
            c_to_save : out std_logic_vector(7 downto 0);
    
            increment_count : out std_logic;
            curr_count : in std_logic_vector(9 downto 0);

            set_zero : out std_logic;
            get_zero: in std_logic;
            en_ff : out std_logic
        );
    end component;

begin
    word_register : register_8bit
        port map(
            clk => i_clk,
            rst => rst_reg,
            en_register => en_word_r,
            new_value => w_to_save,
            saved_value => last_word
        );
    
    credibility_register : register_8bit
        port map(
            clk => i_clk,
            rst => rst_reg,
            en_register => en_cred_r,
            new_value => c_to_save,
            saved_value => last_credibility
        ); 
    
    k_counter : counter
        port map(
            increment_count => increment_count,
            clk => i_clk,
            rst => rst_reg,
            curr_count => curr_count
        );
    
    zero_ff : ff_d
        port map(
            clk => i_clk,
            rst => rst_reg,
            input => set_zero, 
            output => get_zero,
            en_ff => en_ff
        );

    fsm_controller : fsm
        port map(
            i_clk => i_clk,
            i_rst => i_rst,
            i_start => i_start,
            i_add => i_add,
            i_k => i_k,
            o_done => o_done,
            o_mem_addr => o_mem_addr,
            i_mem_data => i_mem_data,
            o_mem_data => o_mem_data,
            o_mem_we => o_mem_we,
            o_mem_en => o_mem_en,
            rst_reg => rst_reg,
            last_word => last_word,
            en_word_r => en_word_r,
            w_to_save => w_to_save,
            last_credibility => last_credibility,
            en_cred_r => en_cred_r,
            c_to_save => c_to_save,
            increment_count => increment_count,
            curr_count => curr_count,
            set_zero => set_zero,
            get_zero => get_zero,
            en_ff => en_ff
        );
end project_reti_logiche_arch;
