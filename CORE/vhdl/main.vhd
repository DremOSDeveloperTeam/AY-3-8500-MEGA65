----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Wrapper for the MiSTer core that runs exclusively in the core's clock domanin
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_modes_pkg.all;

-- Clock divider (used for 2 MHz clock)
-- I just lifted this from here: https://surf-vhdl.com/how-to-implement-clock-divider-vhdl/
entity clock_div is
port(
  i_clk         : in  std_logic;
  i_rst         : in  std_logic;
  i_clk_divider : in  std_logic_vector(3 downto 0);
  o_clk         : out std_logic);
end clock_div;
architecture synthesis of clock_div is
signal r_clk_counter        : unsigned(3 downto 0);
signal r_clk_divider        : unsigned(3 downto 0);
signal r_clk_divider_half   : unsigned(3 downto 0);
begin
p_clk_divider: process(i_rst,i_clk)
begin
  if(i_rst='0') then
    r_clk_counter       <= (others=>'0');
    r_clk_divider       <= (others=>'0');
    r_clk_divider_half  <= (others=>'0');
    o_clk               <= '0';
  elsif(rising_edge(i_clk)) then
    r_clk_divider       <= unsigned(i_clk_divider)-1;
    r_clk_divider_half  <= unsigned('0'&i_clk_divider(3 downto 1)); -- half
    if(r_clk_counter < r_clk_divider_half) then 
      r_clk_counter   <= r_clk_counter + 1;
      o_clk           <= '0';
    elsif(r_clk_counter = r_clk_divider) then
      r_clk_counter   <= (others=>'0');
      o_clk           <= '1';
    else
      r_clk_counter   <= r_clk_counter + 1;
      o_clk           <= '1';
    end if;
  end if;
end process p_clk_divider;
end synthesis;

-- Blankinator (glue logic that handles blanking)
-- Translated from the logic in AY-3-8500.sv (SystemVerilog to vHDL)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_modes_pkg.all;

entity blankinator is
    port (
        i_clk_2m        : in std_logic;
        i_rst           : in std_logic;
        i_vsync         : in std_logic;
        i_hsync         : in std_logic;
        o_vblank        : out std_logic;
        o_hblank        : out std_logic
    );
end blankinator;
architecture synthesis of blankinator is
    signal hcnt         : std_logic_vector(9 downto 0);
    signal vcnt         : std_logic_vector(9 downto 0);
    signal old_hs       : std_logic;
    signal old_vs       : std_logic;
begin
    p_blankinator: process(i_clk_2m, i_rst)
    begin
        if(i_rst='1') then
            hcnt    <= (others=>'0');
            vcnt    <= (others=>'0');
            old_hs  <= '0';
            old_vs  <= '0';
        elsif(rising_edge(i_clk_2m)) then
            hcnt <= std_logic_vector(unsigned(hcnt)+1);
            old_hs <= i_hsync;
            if(old_hs and (not i_hsync)) then
                hcnt    <= (others=>'0');
                
                vcnt    <= std_logic_vector(unsigned(vcnt)+1);
                old_vs  <= i_vsync;
                if(old_vs and (not i_vsync)) then vcnt <= (others=>'0'); end if;
            end if;
            
            if (hcnt = std_logic_vector(to_unsigned(21, 10)))   then o_hblank <= '0'; end if;
            if (hcnt = std_logic_vector(to_unsigned(100, 10)))  then o_hblank <= '1'; end if;
            if (vcnt = std_logic_vector(to_unsigned(34, 10)))   then o_vblank <= '0'; end if;
            if (vcnt = std_logic_vector(to_unsigned(240, 10)))  then o_vblank <= '1'; end if;
        end if;
    end process p_blankinator;
end synthesis;

-- Main (the actual core)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_modes_pkg.all;

entity main is
   generic (
      G_VDNUM                 : natural                     -- amount of virtual drives
   );
   port (
      clk_main_i              : in  std_logic;
      reset_soft_i            : in  std_logic;
      reset_hard_i            : in  std_logic;
      pause_i                 : in  std_logic;

      -- MiSTer core main clock speed:
      -- Make sure you pass very exact numbers here, because they are used for avoiding clock drift at derived clocks
      clk_main_speed_i        : in  natural;

      -- Video output
      video_ce_o              : out std_logic;
      video_ce_ovl_o          : out std_logic;
      video_red_o             : out std_logic_vector(7 downto 0);
      video_green_o           : out std_logic_vector(7 downto 0);
      video_blue_o            : out std_logic_vector(7 downto 0);
      video_vs_o              : out std_logic;
      video_hs_o              : out std_logic;
      video_hblank_o          : out std_logic;
      video_vblank_o          : out std_logic;

      -- Audio output (Signed PCM)
      audio_left_o            : out signed(15 downto 0);
      audio_right_o           : out signed(15 downto 0);

      -- M2M Keyboard interface
      kb_key_num_i            : in  integer range 0 to 79;    -- cycles through all MEGA65 keys
      kb_key_pressed_n_i      : in  std_logic;                -- low active: debounced feedback: is kb_key_num_i pressed right now?

      -- MEGA65 joysticks and paddles/mouse/potentiometers
      joy_1_up_n_i            : in  std_logic;
      joy_1_down_n_i          : in  std_logic;
      joy_1_left_n_i          : in  std_logic;
      joy_1_right_n_i         : in  std_logic;
      joy_1_fire_n_i          : in  std_logic;

      joy_2_up_n_i            : in  std_logic;
      joy_2_down_n_i          : in  std_logic;
      joy_2_left_n_i          : in  std_logic;
      joy_2_right_n_i         : in  std_logic;
      joy_2_fire_n_i          : in  std_logic;

      pot1_x_i                : in  std_logic_vector(7 downto 0);
      pot1_y_i                : in  std_logic_vector(7 downto 0);
      pot2_x_i                : in  std_logic_vector(7 downto 0);
      pot2_y_i                : in  std_logic_vector(7 downto 0)
   );
end entity main;

architecture synthesis of main is

-- @TODO: Remove these demo core signals
--signal keyboard_n          : std_logic_vector(79 downto 0);

-- ay38500NTSC component declaration
component ay38500NTSC is
    port (
        -- @TODO All wiring
        -- I think this is roughly how this should work, but for now I'm only
        --   focusing on video and clocks to get a sign of life!    
        -- pinRPout              : out std_logic;
        -- pinLPout              : out std_logic;
        -- pinBallOut            : out std_logic;
        -- pinManualServe        : in std_logic
        clk                   : in std_logic;   -- 2 (or 6 MHz..?)
        superclock            : in std_logic;   -- 48 MHz
        reset                 : in std_logic;   -- Reset pin
        syncH                 : out std_logic;  -- Horizontal sync
        syncV                 : out std_logic;  -- Vertical sync
        pinRPout              : out std_logic;  -- Right player output
        pinLPout              : out std_logic;  -- Left player output
        pinSFout              : out std_logic;  -- Score field out
        pinSound              : out std_logic   -- Chip's sound
        
    );
end component ay38500NTSC;


signal ce_2m                  : std_logic;      -- A 2 MHz clock signal derived from the main 48 MHz clock (48/24)
signal ce_6m                  : std_logic;      -- A 6 MHz clock signal used for the pixel clock (48/8)

signal chip_video_hs          : std_logic;      -- Chip's hs
signal chip_video_vs          : std_logic;      -- Chip's hs
signal chip_video_field       : std_logic;      -- Chip score field, 
signal chip_video_rp          : std_logic;      -- Right player video
signal chip_video_lp          : std_logic;      -- Left player video
signal chip_video             : std_logic;      -- Final video signal for the chip.
signal chip_ball              : std_logic;      -- Chip ball output @TODO make it possible to hide
signal chip_sound             : std_logic;      -- Chip's sound pin

begin

     i_ce_2m       : entity work.clock_div
        port map (
            i_clk           => clk_main_i,
            i_rst           => reset_soft_i or reset_hard_i,
            i_clk_divider   => std_logic_vector(to_unsigned(24, 4)), -- integer 24 --> unsigned(3 downto 0)
            o_clk           => ce_2m
        );
        
     i_ce_6m      : entity work.clock_div
        port map(
            i_clk           => clk_main_i,
            i_rst           => reset_soft_i or reset_hard_i,
            i_clk_divider   => std_logic_vector(to_unsigned(8, 4)),
            o_clk           => ce_6m
        );
        
     i_blankinator : entity work.blankinator
        port map (
            i_clk_2m        => ce_2m,
            i_rst           => reset_soft_i or reset_hard_i,
            i_vsync         => chip_video_vs,
            i_hsync         => chip_video_hs,
            o_vblank        => video_vblank_o,
            o_hblank        => video_hblank_o
        );

     i_ay38500NTSC : ay38500NTSC
        port map (
            clk               => ce_2m,                             -- @TODO allow change to 6 MHz for "arcade graphics"... whatever that means
            superclock        => clk_main_i,
            reset             => reset_soft_i or reset_hard_i,      -- Long and short press of reset button mean the same
            syncH             => chip_video_hs,
            syncV             => chip_video_vs,
            pinRPout          => chip_video_rp,
            pinLPout          => chip_video_lp,
            pinSFout          => chip_video_field,
            pinSound          => chip_sound
        ); -- i_ay38500NTSC (the chip itself)
        
        -- The below connects ALL video signals to chip_video.
        -- @TODO make it possible to hide elements (such as players or the ball). Maybe.
        chip_video          <= chip_ball;           -- Ball         --> AV video output
        chip_video          <= chip_video_field;    -- Field        --> AV video output
        chip_video          <= chip_video_lp;       -- Left player  --> AV video output
        chip_video          <= chip_video_rp;       -- Right player --> AV video output
        
        -- Connect chip video output to the main video output
        -- @TODO color logic. Currently black and white ONLY
        video_red_o           <= (others=>chip_video);
        video_green_o         <= (others=>chip_video);
        video_blue_o          <= (others=>chip_video);
        video_hs_o            <= chip_video_hs;
        video_vs_o            <= chip_video_vs;
        
    /*i_chip : module work.ay38500NTSC
        port map (
        
        );*/
   -- @TODO: Add the actual MiSTer core here
   -- The demo core's purpose is to show a test image and to make sure, that the MiSTer2MEGA65 framework
   -- can be synthesized and run stand-alone without an actual MiSTer core being there, yet
   /*i_democore : entity work.democore
      port map (
         clk_main_i           => clk_main_i,

         reset_i              => reset_soft_i or reset_hard_i,       -- long and short press of reset button mean the same
         pause_i              => pause_i,

         ball_col_rgb_i       => x"EE4020",                          -- ball color (RGB): orange
         paddle_speed_i       => x"1",                               -- paddle speed is about 50 pixels / sec (due to 50 Hz)

         keyboard_n_i         => keyboard_n,                         -- move the paddle with the cursor left/right keys...
         joy_up_n_i           => joy_1_up_n_i,                       -- ... or move the paddle with a joystick in port #1
         joy_down_n_i         => joy_1_down_n_i,
         joy_left_n_i         => joy_1_left_n_i,
         joy_right_n_i        => joy_1_right_n_i,
         joy_fire_n_i         => joy_1_fire_n_i,

         vga_ce_o             => video_ce_o,
         vga_red_o            => video_red_o,
         vga_green_o          => video_green_o,
         vga_blue_o           => video_blue_o,
         vga_vs_o             => video_vs_o,
         vga_hs_o             => video_hs_o,
         vga_hblank_o         => video_hblank_o,
         vga_vblank_o         => video_vblank_o,

         audio_left_o         => audio_left_o,
         audio_right_o        => audio_right_o
      );*/ -- i_democore

   -- On video_ce_o and video_ce_ovl_o: You have an important @TODO when porting a core:
   -- video_ce_o: You need to make sure that video_ce_o divides clk_main_i such that it transforms clk_main_i
   --             into the pixelclock of the core (means: the core's native output resolution pre-scandoubler)
   -- video_ce_ovl_o: Clock enable for the OSM overlay and for sampling the core's (retro) output in a way that
   --             it is displayed correctly on a "modern" analog input device: Make sure that video_ce_ovl_o
   --             transforms clk_main_o into the post-scandoubler pixelclock that is valid for the target
   --             resolution specified by VGA_DX/VGA_DY (globals.vhd)
   -- video_retro15kHz_o: '1', if the output from the core (post-scandoubler) in the retro 15 kHz analog RGB mode.
   --             Hint: Scandoubler off does not automatically mean retro 15 kHz on.
   video_ce_o     <= ce_6m;
   video_ce_ovl_o <= video_ce_o;
   --video_retro15khz_o   <= '1'; -- Just set qnice_retro15kHz_o to 1 manually (mega65.vhd)

   -- @TODO: Keyboard mapping and keyboard behavior
   -- Each core is treating the keyboard in a different way: Some need low-active "matrices", some
   -- might need small high-active keyboard memories, etc. This is why the MiSTer2MEGA65 framework
   -- lets you define literally everything and only provides a minimal abstraction layer to the keyboard.
   -- You need to adjust keyboard.vhd to your needs
   /*i_keyboard : entity work.keyboard
      port map (
         clk_main_i           => clk_main_i,

         -- Interface to the MEGA65 keyboard
         key_num_i            => kb_key_num_i,
         key_pressed_n_i      => kb_key_pressed_n_i,

         -- @TODO: Create the kind of keyboard output that your core needs
         -- "example_n_o" is a low active register and used by the demo core:
         --    bit 0: Space
         --    bit 1: Return
         --    bit 2: Run/Stop
         example_n_o          => keyboard_n
      );*/ -- i_keyboard

end architecture synthesis;

