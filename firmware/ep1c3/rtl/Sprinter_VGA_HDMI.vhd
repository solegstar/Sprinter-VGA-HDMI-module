-----------------------------------------------------------------------------------------------------------------------------------------------------------------
--         .-+%########%+:.                                               +#######################%+:-                                                         --
--      :###################@.                                           .############@=+:.                                                                    --
--    :#########*---=#########.                                          +#@=*-.                             .-*=%###                                          --
--   *########-      *########               ..                                                             .#######:              ..                          --
--   =#########%*.             +#######-%##########:   .#######*-@####+ %#######. %#######-@##########- -###############+  .*#############%.    #######+-%####%--
--   .@###############@+-     .##########=+=########%  +##############.:#######* -#####################.%###############.-#######+--*@######+  *##############.--
--      -=#################-  =#######=      %#######..##########=***- @######@  %#######:     ########    @######=     %######-     .#######  ##########=***- --
--             -*%########## .#######=       #######@ =#######+       *#######: :#######*     *#######:   *#######.    %####################% +#######=        --
--########:        %#######@ =#######.      =#######--#######+       .#######%  @######@      #######@    #######+    -#######==============-.#######=         --
--#########+.   .*########@.-########-    .########. %#######        +#######- *#######:     *#######-   +#######-    :######%     .%######* =#######.         --
--.@####################@-  @####################:  :#######*       .#######=  #######%     .#######%    ############- %########@@#######@. -#######+          --
--   .*@############%:.    :#######+-@#######@:.    @######@        =#######. +#######-     =#######.    .%#########=   .*@##########@+.    %#######.          --
--                         ########.                                                                                                                           --
--                        *#######*                                                                                                                            --
--                       .#@%+:..                                                                                                                              --
--																																							   --
-- https://github.com/solegstar/Sprinter-VGA-HDMI-module																									   --
--																																							   --
-- FPGA firmware for Sprinter VGA Module																													   --
--																																							   --
-- @author Andy Karpov <andy.karpov@gmail.com>																												   --
-- @HDMI codec by MVV <https://github.com/mvvproject/ReVerSE-U16>																							   --
-- @author Oleh Starychenko <solegstar@gmail.com>																											   --
-- Ukraine, 2025																																			   --
-----------------------------------------------------------------------------------------------------------------------------------------------------------------

library IEEE; 
use IEEE.std_logic_1164.all; 
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all; 

entity Sprinter_VGA_HDMI is

port (
	-- Clocks
	TG42 		: in std_logic := '0';
	WR_COL		: in std_logic := '0';
	CLK_PLL_IN 	: in std_logic := '0';
	CLK_PLL_OUT : out std_logic := '0';
	CLK_7125	: out std_logic := '0';

	-- TV IN
	TV_R 		: in std_logic_vector(7 downto 0) := "00000000";
	TV_G 		: in std_logic_vector(7 downto 0) := "00000000";
	TV_B 		: in std_logic_vector(7 downto 0) := "00000000";
	TV_HS 		: in std_logic := '0';
	TV_VS 		: in std_logic := '0';
	TV_SYNC 	: in std_logic := '0';
	TV_nSYNC 	: out std_logic;
	TV_nBLANK 	: out std_logic;
	TV_nSYNC_IN : in std_logic := '0';
	TV_SYNC_IN 	: out std_logic;
	
	-- ADC
	ADC_CLK		: out std_logic := '1';
	ADC_LRCK	: out std_logic := '1';
	ADC_BCK		: out std_logic := '1';
	ADC_DOUT	: in std_logic := '1';
	
	-- HDMI
	HDMI_SCL	: in std_logic := '0';
	HDMI_SDA	: in std_logic := '0';
	HDMI_CEC	: in std_logic := '0';
	HDMI_ARC	: in std_logic := '0';
	HDMI_DET	: in std_logic := '0';
	tmds_out_p	: out std_logic_vector (3 downto 0);
--	tmds_out_n	: out std_logic_vector (3 downto 0);

	-- VGA 
	VGA_nVGA_IN : in std_logic := '1';
	VGA_VGA_IN	: out std_logic;
	VGA_R 		: out std_logic_vector(7 downto 0);
	VGA_G 		: out std_logic_vector(7 downto 0);
	VGA_B 		: out std_logic_vector(7 downto 0);
	VGA_HS 		: out std_logic;
	VGA_VS 		: out std_logic
	);
end Sprinter_VGA_HDMI;

architecture rtl of Sprinter_VGA_HDMI is

signal CLK_PIXEL_TV	: std_logic := '0';
signal CLK_VGA		: std_logic := '0';
signal CLK_DVI		: std_logic := '0';
signal CLK_PIXEL_VGA: std_logic := '0';
signal locked		: std_logic;
signal TV_VS_REG	: std_logic;
signal TV_HS_REG	: std_logic;
signal TV_R_REG		: std_logic_vector(7 downto 0) := "00000000";
signal TV_G_REG		: std_logic_vector(7 downto 0) := "00000000";
signal TV_B_REG		: std_logic_vector(7 downto 0) := "00000000";
signal VGA_R_REG	: std_logic_vector(7 downto 0) := "00000000";
signal VGA_G_REG	: std_logic_vector(7 downto 0) := "00000000";
signal VGA_B_REG	: std_logic_vector(7 downto 0) := "00000000";
signal VGA_BLANK	: std_logic := '0';
signal VGA_VS_O		: std_logic := '0';
signal VGA_HS_O		: std_logic := '0';
signal audio_l		: std_logic_vector(15 downto 0) := "0000000000000000";
signal audio_r		: std_logic_vector(15 downto 0) := "0000000000000000";
signal adc_l		: std_logic_vector(23 downto 0) := x"000000";
signal adc_r		: std_logic_vector(23 downto 0) := x"000000";
signal O_RED		: std_logic_vector(9 downto 0); -- Red
signal O_GREEN		: std_logic_vector(9 downto 0); -- Green
signal O_BLUE		: std_logic_vector(9 downto 0);  -- Blue
signal RGB_REG		: std_logic_vector(29 downto 0); -- RGB reg for serializer

begin

-- PLL1
U1: entity work.altpll0
port map (
	inclk0			=> TG42,
	locked			=> locked,
	c0 				=> CLK_DVI,
	c1 				=> CLK_PIXEL_VGA,
	e0 				=> CLK_PLL_OUT
	);
	
-- Scandoubler	
U2: entity work.vga_pal 
port map (
	RGB_IN 				=> TV_R_REG&TV_G_REG&TV_B_REG,
	KSI_IN 				=> not TV_VS,
	SSI_IN 				=> not TV_HS,
	CLK 				=> CLK_PIXEL_TV,
	CLK2 				=> CLK_VGA,
	DS80				=> '0',		
	RGB_O(23 downto 16)	=> VGA_R_REG,
	RGB_O(15 downto 8)	=> VGA_G_REG,
	RGB_O(7 downto 0)	=> VGA_B_REG,
	VGA_BLANK_O 		=> VGA_BLANK,
	VSYNC_VGA			=> VGA_VS_O,
	HSYNC_VGA			=> VGA_HS_O
);

U3: entity work.i2s_transceiver
port map (
	reset_n		=> locked,
	mclk		=> CLK_VGA,
	sclk		=> ADC_BCK,
	ws			=> ADC_LRCK,
	sd_tx		=> open,
	sd_rx		=> ADC_DOUT,
	l_data_tx	=> x"000000",
	r_data_tx	=> x"000000",
	l_data_rx	=> adc_l,
	r_data_rx	=> adc_r
	);

-- HDMI
U4: entity work.hdmi
   port map(
      -- clocks
      I_CLK_PIXEL	=> CLK_PIXEL_VGA,
      -- components
      I_R			=> VGA_R_REG(0)&VGA_R_REG(1)&VGA_R_REG(2)&VGA_R_REG(3)&VGA_R_REG(4)&VGA_R_REG(5)&VGA_R_REG(6)&VGA_R_REG(7),
      I_G			=> VGA_G_REG(0)&VGA_G_REG(1)&VGA_G_REG(2)&VGA_G_REG(3)&VGA_G_REG(4)&VGA_G_REG(5)&VGA_G_REG(6)&VGA_G_REG(7),
      I_B			=> VGA_B_REG(0)&VGA_B_REG(1)&VGA_B_REG(2)&VGA_B_REG(3)&VGA_B_REG(4)&VGA_B_REG(5)&VGA_B_REG(6)&VGA_B_REG(7),
      I_BLANK		=> not VGA_BLANK,
      I_HSYNC		=> VGA_HS_O,
      I_VSYNC		=> VGA_VS_O,
      I_576P_N		=> '0',
      -- PCM audio
      I_AUDIO_ENABLE	=> '1',
      I_AUDIO_PCM_L		=> audio_l,
      I_AUDIO_PCM_R		=> audio_r,
      -- TMDS parallel pixel synchronous outputs (serialize LSB first)
      O_RED				=> O_RED,
      O_GREEN			=> O_GREEN,
      O_BLUE			=> O_BLUE
		);

-- ALTDDIO outputs
--U5: entity work.hdmi_out_altera
--	port map (
--		clock_pixel_i	=> CLK_PIXEL_VGA,
--		clock_tdms_i	=> CLK_DVI,
--		red_i			=> O_RED,
--		green_i			=> O_GREEN,
--		blue_i			=> O_BLUE,
--		tmds_out_p		=> tmds_out_p,
--		tmds_out_n		=> tmds_out_n
--		);

-- LVDS outputs
U5: entity work.serializer
	PORT MAP (
		tx_in	 		=> RGB_REG,
		tx_inclock	 	=> CLK_DVI,
		tx_syncclock	=> CLK_PIXEL_VGA,
		tx_out	 		=> tmds_out_p (2 downto 0)
		);

RGB_REG <=	O_RED(0)&	O_RED(1)&	O_RED(2)&	O_RED(3)&	O_RED(4)&	O_RED(5)&	O_RED(6)&	O_RED(7)&	O_RED(8)&	O_RED(9)&
			O_GREEN(0)&	O_GREEN(1)&	O_GREEN(2)&	O_GREEN(3)&	O_GREEN(4)&	O_GREEN(5)&	O_GREEN(6)&	O_GREEN(7)&	O_GREEN(8)&	O_GREEN(9)&
			O_BLUE(0)&	O_BLUE(1)&	O_BLUE(2)&	O_BLUE(3)&	O_BLUE(4)&	O_BLUE(5)&	O_BLUE(6)&	O_BLUE(7)&	O_BLUE(8)&	O_BLUE(9);

tmds_out_p(3) <= CLK_PIXEL_VGA;
---
-------------------------------------------------------------------------------
-- clocks
-- video

CLK_VGA <= CLK_PLL_IN and CLK_PIXEL_VGA;

process (CLK_VGA)
begin 
	if (CLK_VGA'event and CLK_VGA = '1') then 
		CLK_PIXEL_TV <= not(CLK_PIXEL_TV);
		TV_VS_REG <= TV_VS;
		TV_HS_REG <= TV_HS;
		TV_nSYNC <= not TV_SYNC;
		TV_SYNC_IN <= not TV_nSYNC_IN; 
		VGA_VGA_IN	<= not VGA_nVGA_IN;
	end if;
end process;

process (WR_COl, TV_R, TV_G, TV_B, TV_R_REG, TV_G_REG, TV_B_REG)
begin 
	if (WR_COl'event and WR_COl = '1') then 
		TV_R_REG <= TV_R;
		TV_G_REG <= TV_G;
		TV_B_REG <= TV_B;
	end if;
end process;

process (VGA_nVGA_IN, VGA_VS_O, VGA_HS_O, VGA_BLANK, TV_VS, TV_HS, VGA_R_REG, VGA_G_REG, VGA_B_REG, TV_R_REG, TV_G_REG, TV_B_REG,
		CLK_PLL_IN, CLK_PIXEL_VGA, TV_VS_REG, TV_HS_REG, CLK_PIXEL_TV) 
begin
	if (VGA_nVGA_IN = '0') then 
		VGA_VS <= VGA_VS_O;      -- кадровые синхроимпульсы для VGA
		VGA_HS <= VGA_HS_O;      -- строчные синхроимпульсы для VGA
		VGA_R <= VGA_R_REG;
		VGA_G <= VGA_G_REG;
		VGA_B <= VGA_B_REG;
		if (VGA_BLANK = '0') then
			TV_nBLANK <= '0';
		else
			TV_nBLANK <= 'Z';
		end if;
		CLK_7125 <= CLK_PLL_IN and VGA_BLANK;
	else 
		VGA_VS <= TV_VS_REG;
		VGA_HS <= TV_HS_REG;
		TV_nBLANK <= not (TV_VS_REG or TV_HS_REG);
		VGA_R <= TV_R_REG;
		VGA_G <= TV_G_REG;
		VGA_B <= TV_B_REG;
		CLK_7125 <= not (TV_VS_REG or TV_HS_REG) and CLK_PIXEL_TV;
	end if;
end process;

-- audio
ADC_CLK <= CLK_VGA;

process (CLK_PIXEL_VGA, adc_l, adc_r, audio_l, audio_r)
begin
	if CLK_PIXEL_VGA'event and CLK_PIXEL_VGA = '1' then
		audio_l (15 downto 0) <= adc_l (23 downto 8);
		audio_r (15 downto 0) <= adc_r (23 downto 8);
	end if;
end process;

end rtl;
