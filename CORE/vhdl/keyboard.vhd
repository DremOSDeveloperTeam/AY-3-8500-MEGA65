---------------------------------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework  
--
-- Custom keyboard controller for your core
--
-- Runs in the clock domain of the core.
--
-- This is how MiSTer2MEGA65 provides access to the MEGA65 keyboard: 
--
-- Each core is treating the keyboard in a different way: Some need low-active "matrices", some
-- might need small high-active keyboard memories, etc. This is why the MiSTer2MEGA65 framework
-- lets you define literally everything and only provides a minimal abstraction layer to the keyboard.
-- You need to adjust this module to your needs.
--
-- MiSTer2MEGA65 provides a very simple and generic interface to the MEGA65 keyboard:
-- kb_key_num_i is running through the key numbers 0 to 79 with a frequency of 1 kHz, i.e. the whole
-- keyboard is scanned 1000 times per second. kb_key_pressed_n_i is already debounced and signals
-- low active, if a certain key is being pressed right now.
-- 
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
---------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity keyboard is
   port (
      clk_main_i           : in std_logic;               -- core clock
      i_rst                : in std_logic;               -- reset
         
      -- Interface to the MEGA65 keyboard
      key_num_i            : in integer range 0 to 79;   -- cycles through all MEGA65 keys
      key_pressed_n_i      : in std_logic;               -- low active: debounced feedback: is kb_key_num_i pressed right now?
               
      -- @TODO: Create the kind of keyboard output that your core needs
      -- "example_n_o" is a low active register and used by the demo core
      example_n_o          : out std_logic_vector(79 downto 0);
      
      manual_serve_o       : out std_logic;               -- When held low, manual serve is on. If manual serve is off, space will serve.
      paddle_size_o        : out std_logic;               -- Paddle size, default large (1)
      ball_speed_o         : out std_logic;               -- Ball speed, default normal (1)
      ball_angle_o         : out std_logic;               -- Ball angle, default 2 (1)
      game_select_o        : out std_logic_vector(5 downto 0)  -- Game selection
   );
end keyboard;

architecture beh of keyboard is

-- MEGA65 key codes that kb_key_num_i is using while
-- kb_key_pressed_n_i is signalling (low active) which key is pressed
constant m65_ins_del       : integer := 0;
constant m65_return        : integer := 1;
constant m65_horz_crsr     : integer := 2;   -- means cursor right in C64 terminology
constant m65_f7            : integer := 3;
constant m65_f1            : integer := 4;
constant m65_f3            : integer := 5;
constant m65_f5            : integer := 6;
constant m65_vert_crsr     : integer := 7;   -- means cursor down in C64 terminology
constant m65_3             : integer := 8;
constant m65_w             : integer := 9;
constant m65_a             : integer := 10;
constant m65_4             : integer := 11;
constant m65_z             : integer := 12;
constant m65_s             : integer := 13;
constant m65_e             : integer := 14;
constant m65_left_shift    : integer := 15;
constant m65_5             : integer := 16;
constant m65_r             : integer := 17;
constant m65_d             : integer := 18;
constant m65_6             : integer := 19;
constant m65_c             : integer := 20;
constant m65_f             : integer := 21;
constant m65_t             : integer := 22;
constant m65_x             : integer := 23;
constant m65_7             : integer := 24;
constant m65_y             : integer := 25;
constant m65_g             : integer := 26;
constant m65_8             : integer := 27;
constant m65_b             : integer := 28;
constant m65_h             : integer := 29;
constant m65_u             : integer := 30;
constant m65_v             : integer := 31;
constant m65_9             : integer := 32;
constant m65_i             : integer := 33;
constant m65_j             : integer := 34;
constant m65_0             : integer := 35;
constant m65_m             : integer := 36;
constant m65_k             : integer := 37;
constant m65_o             : integer := 38;
constant m65_n             : integer := 39;
constant m65_plus          : integer := 40;
constant m65_p             : integer := 41; 
constant m65_l             : integer := 42;
constant m65_minus         : integer := 43;
constant m65_dot           : integer := 44;
constant m65_colon         : integer := 45;
constant m65_at            : integer := 46;
constant m65_comma         : integer := 47;
constant m65_gbp           : integer := 48;
constant m65_asterisk      : integer := 49;
constant m65_semicolon     : integer := 50;
constant m65_clr_home      : integer := 51;
constant m65_right_shift   : integer := 52;
constant m65_equal         : integer := 53;
constant m65_arrow_up      : integer := 54;  -- symbol, not cursor
constant m65_slash         : integer := 55;
constant m65_1             : integer := 56;
constant m65_arrow_left    : integer := 57;  -- symbol, not cursor
constant m65_ctrl          : integer := 58;
constant m65_2             : integer := 59;
constant m65_space         : integer := 60;
constant m65_mega          : integer := 61;
constant m65_q             : integer := 62;
constant m65_run_stop      : integer := 63;
constant m65_no_scrl       : integer := 64;
constant m65_tab           : integer := 65;
constant m65_alt           : integer := 66;
constant m65_help          : integer := 67;
constant m65_f9            : integer := 68;
constant m65_f11           : integer := 69;
constant m65_f13           : integer := 70;
constant m65_esc           : integer := 71;
constant m65_capslock      : integer := 72;
constant m65_up_crsr       : integer := 73;  -- cursor up
constant m65_left_crsr     : integer := 74;  -- cursor left
constant m65_restore       : integer := 75;

-- Games
constant game_tennis          : integer := 0;
constant game_soccer          : integer := 1;
constant game_squash          : integer := 2;
constant game_practice        : integer := 3;
constant game_rifle1          : integer := 4;
constant game_rifle2          : integer := 5;

signal key_pressed_n        : std_logic_vector(79 downto 0);
signal manual_serve_held    : std_logic;
signal paddle_size_held     : std_logic;
signal ball_speed_held      : std_logic;
signal ball_angle_held      : std_logic;

-- Game controls

begin

   example_n_o                 <= key_pressed_n;
      
   keyboard_state : process(clk_main_i)
   begin
      if rising_edge(clk_main_i) then
         key_pressed_n(key_num_i) <= key_pressed_n_i;
      end if;
   end process;

   controls_mgr   : process(clk_main_i, i_rst)
   begin
      if (i_rst='1') then
        manual_serve_o              <= '1';
        paddle_size_o               <= '1';
        ball_speed_o                <= '1';
        ball_angle_o                <= '1';
        game_select_o               <= "111111";
        game_select_o(game_tennis)  <= '0';
        
        manual_serve_held           <= '0';
        paddle_size_held            <= '0';
        ball_speed_held             <= '0';
        ball_angle_held             <= '0';
      else
        if rising_edge(clk_main_i) then
            -- Toggle for manual serve.
            if (key_pressed_n(m65_v) = '0') then -- On V key strike, changes manual serve.
                if (not manual_serve_held) then
                    manual_serve_o      <= not manual_serve_o;
                    manual_serve_held   <= '1';
                end if;
            else
                manual_serve_held       <= '0';
            end if;
            
            -- This handles manual serving.
            if (manual_serve_o = '1') then
                if (key_pressed_n(m65_space) = '0') then
                    manual_serve_o         <= '1';
                else
                    manual_serve_o         <= '0';
                end if;
            end if;
            
            -- This handles paddle/bat size
            if (key_pressed_n(m65_c) = '0') then
                if (not paddle_size_held) then
                    paddle_size_o       <= not paddle_size_o;
                    paddle_size_held    <= '1';
                end if;
            else
                paddle_size_held        <= '0';
            end if;
            
            -- This handles ball speed
            if (key_pressed_n(m65_x) = '0') then
                if (not ball_speed_held) then
                    ball_speed_o    <= not ball_speed_o;
                    ball_speed_held <= '1';
                end if;
            else
                ball_speed_held     <= '0';
            end if;
            
            -- This handles ball angle
            if (key_pressed_n(m65_z) = '0') then
                if (not ball_angle_held) then
                    ball_angle_o    <= not ball_angle_o;
                    ball_angle_held <= '1';
                end if;
            else
                ball_angle_held     <= '0';
            end if;
            
            -- This handles game selection.
            -- Wow this is ugly code, but at least I know this works.
            -- @TODO make this unugly code.
            if    (key_pressed_n(m65_1) = '0' and game_select_o(game_tennis) = '1') then
                game_select_o               <= "111111";
                game_select_o(game_tennis)  <= '0';
            elsif (key_pressed_n(m65_2) = '0' and game_select_o(game_soccer) = '1') then
                game_select_o               <= "111111";
                game_select_o(game_soccer)  <= '0';
            elsif (key_pressed_n(m65_3) = '0' and game_select_o /= "111111") then
                game_select_o               <= "111111";
            elsif (key_pressed_n(m65_4) = '0' and game_select_o(game_squash) = '1') then
                game_select_o               <= "111111";
                game_select_o(game_squash)  <= '0';
            elsif (key_pressed_n(m65_5) = '0' and game_select_o(game_practice) = '1') then
                game_select_o               <= "111111";
                game_select_o(game_practice)<= '0';
            elsif (key_pressed_n(m65_6) = '0' and game_select_o(game_rifle1) = '1') then
                game_select_o               <= "111111";
                game_select_o(game_rifle1)  <= '0';
            elsif (key_pressed_n(m65_7) = '0' and game_select_o(game_rifle2) = '1') then
                game_select_o               <= "111111";
                game_select_o(game_rifle2)  <= '0';
            end if;
        end if;
      end if;
   end process;

   /*signal 
   keyboard_pots  : process(clk_main_i)
   begin
      if rising_edge(clk_main_i) then
         if (key_pressed_n(9) = '0') then
         
         elsif (key_pressed_n(13) = '0') then
         
         end if;
      end if;
   end process;*/

end beh;

/*library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
entity keyboard_mgr is
    port (
        clk_main_i           : in std_logic;               -- core clock
        key_pressed_n
        
        emupot1_o            : out std_logic_vector(7 downto 0);
        emupot2_o            : out std_logic_vector(7 downto 0)
    );
end keyboard_mgr;

architecture synthesis of keyboard_mgr is
    p_managepots : process(clk_main_i)
    begin
        if rising_edge(clk_main_i) then
        
        end if;
    end process;
begin

end synthesis;*/