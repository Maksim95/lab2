-------------------------------------------------------------------------------
--  Department of Computer Engineering and Communications
--  Author: LPRS2  <lprs2@rt-rk.com>
--
--  Module Name: top
--
--  Description:
--
--    Simple test for VGA control
--
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity top is
  generic (
    RES_TYPE             : natural := 1;
    TEXT_MEM_DATA_WIDTH  : natural := 6;
    GRAPH_MEM_DATA_WIDTH : natural := 32
    );
  port (
    clk_i          : in  std_logic;
    reset_n_i      : in  std_logic;
	 direct_mode_i  : in  std_logic;
	 display_mode_i : in  std_logic_vector(1 downto 0);
    -- vga
    vga_hsync_o    : out std_logic;
    vga_vsync_o    : out std_logic;
    blank_o        : out std_logic;
    pix_clock_o    : out std_logic;
    psave_o        : out std_logic;
    sync_o         : out std_logic;
    red_o          : out std_logic_vector(7 downto 0);
    green_o        : out std_logic_vector(7 downto 0);
    blue_o         : out std_logic_vector(7 downto 0)
   );
end top;

architecture rtl of top is

  constant RES_NUM : natural := 6;

  type t_param_array is array (0 to RES_NUM-1) of natural;
  
  constant H_RES_ARRAY           : t_param_array := ( 0 => 64, 1 => 640,  2 => 800,  3 => 1024,  4 => 1152,  5 => 1280,  others => 0 );
  constant V_RES_ARRAY           : t_param_array := ( 0 => 48, 1 => 480,  2 => 600,  3 => 768,   4 => 864,   5 => 1024,  others => 0 );
  constant MEM_ADDR_WIDTH_ARRAY  : t_param_array := ( 0 => 12, 1 => 14,   2 => 13,   3 => 14,    4 => 14,    5 => 15,    others => 0 );
  constant MEM_SIZE_ARRAY        : t_param_array := ( 0 => 48, 1 => 4800, 2 => 7500, 3 => 12576, 4 => 15552, 5 => 20480, others => 0 ); 
  
  constant H_RES          : natural := H_RES_ARRAY(RES_TYPE);
  constant V_RES          : natural := V_RES_ARRAY(RES_TYPE);
  constant MEM_ADDR_WIDTH : natural := MEM_ADDR_WIDTH_ARRAY(RES_TYPE);
  constant MEM_SIZE       : natural := MEM_SIZE_ARRAY(RES_TYPE);

  component vga_top is 
    generic (
      H_RES                : natural := 640;
      V_RES                : natural := 480;
      MEM_ADDR_WIDTH       : natural := 32;
      GRAPH_MEM_ADDR_WIDTH : natural := 32;
      TEXT_MEM_DATA_WIDTH  : natural := 32;
      GRAPH_MEM_DATA_WIDTH : natural := 32;
      RES_TYPE             : integer := 1;
      MEM_SIZE             : natural := 4800
      );
    port (
      clk_i               : in  std_logic;
      reset_n_i           : in  std_logic;
      --
      direct_mode_i       : in  std_logic; -- 0 - text and graphics interface mode, 1 - direct mode (direct force RGB component)
      dir_red_i           : in  std_logic_vector(7 downto 0);
      dir_green_i         : in  std_logic_vector(7 downto 0);
      dir_blue_i          : in  std_logic_vector(7 downto 0);
      dir_pixel_column_o  : out std_logic_vector(10 downto 0);
      dir_pixel_row_o     : out std_logic_vector(10 downto 0);
      -- mode interface
      display_mode_i      : in  std_logic_vector(1 downto 0);  -- 00 - text mode, 01 - graphics mode, 01 - text & graphics
      -- text mode interface
      text_addr_i         : in  std_logic_vector(MEM_ADDR_WIDTH-1 downto 0);
      text_data_i         : in  std_logic_vector(TEXT_MEM_DATA_WIDTH-1 downto 0);
      text_we_i           : in  std_logic;
      -- graphics mode interface
      graph_addr_i        : in  std_logic_vector(GRAPH_MEM_ADDR_WIDTH-1 downto 0);
      graph_data_i        : in  std_logic_vector(GRAPH_MEM_DATA_WIDTH-1 downto 0);
      graph_we_i          : in  std_logic;
      --
      font_size_i         : in  std_logic_vector(3 downto 0);
      show_frame_i        : in  std_logic;
      foreground_color_i  : in  std_logic_vector(23 downto 0);
      background_color_i  : in  std_logic_vector(23 downto 0);
      frame_color_i       : in  std_logic_vector(23 downto 0);
      -- vga
      vga_hsync_o         : out std_logic;
      vga_vsync_o         : out std_logic;
      blank_o             : out std_logic;
      pix_clock_o         : out std_logic;
      vga_rst_n_o         : out std_logic;
      psave_o             : out std_logic;
      sync_o              : out std_logic;
      red_o               : out std_logic_vector(7 downto 0);
      green_o             : out std_logic_vector(7 downto 0);
      blue_o              : out std_logic_vector(7 downto 0)
    );
  end component;
	
  component ODDR2
  generic(
   DDR_ALIGNMENT : string := "NONE";
   INIT          : bit    := '0';
   SRTYPE        : string := "SYNC"
   );
  port(
    Q           : out std_ulogic;
    C0          : in  std_ulogic;
    C1          : in  std_ulogic;
    CE          : in  std_ulogic := 'H';
    D0          : in  std_ulogic;
    D1          : in  std_ulogic;
    R           : in  std_ulogic := 'L';
    S           : in  std_ulogic := 'L'
  );
  end component;
  
  
  
  component reg is
	generic(
		WIDTH    : positive := 1;
		RST_INIT : integer := 0
	);
	port(
		i_clk  : in  std_logic;
		in_rst : in  std_logic;
		i_d    : in  std_logic_vector(WIDTH-1 downto 0);
		o_q    : out std_logic_vector(WIDTH-1 downto 0)
	);
end component reg;
  
  
  
  constant update_period     : std_logic_vector(31 downto 0) := conv_std_logic_vector(1, 32);
  
  constant GRAPH_MEM_ADDR_WIDTH : natural := MEM_ADDR_WIDTH + 6;-- graphics addres is scales with minumum char size 8*8 log2(64) = 6
  
  -- text
  signal message_lenght      : std_logic_vector(MEM_ADDR_WIDTH-1 downto 0);
  signal graphics_lenght     : std_logic_vector(GRAPH_MEM_ADDR_WIDTH-1 downto 0);
  
  signal direct_mode         : std_logic;
  --
  signal font_size           : std_logic_vector(3 downto 0);
  signal show_frame          : std_logic;
  signal display_mode        : std_logic_vector(1 downto 0);  -- 01 - text mode, 10 - graphics mode, 11 - text & graphics
  signal foreground_color    : std_logic_vector(23 downto 0);
  signal background_color    : std_logic_vector(23 downto 0);
  signal frame_color         : std_logic_vector(23 downto 0);

  signal char_we             : std_logic;
  signal char_address        : std_logic_vector(MEM_ADDR_WIDTH-1 downto 0);
  signal char_value          : std_logic_vector(5 downto 0);

  signal pixel_address       : std_logic_vector(GRAPH_MEM_ADDR_WIDTH-1 downto 0);
  signal pixel_value         : std_logic_vector(GRAPH_MEM_DATA_WIDTH-1 downto 0);
  signal pixel_we            : std_logic;

  signal pix_clock_s         : std_logic;
  signal vga_rst_n_s         : std_logic;
  signal pix_clock_n         : std_logic;
   
  signal dir_red             : std_logic_vector(7 downto 0);
  signal dir_green           : std_logic_vector(7 downto 0);
  signal dir_blue            : std_logic_vector(7 downto 0);
  signal dir_pixel_column    : std_logic_vector(10 downto 0);
  signal dir_pixel_row       : std_logic_vector(10 downto 0);
  
  signal cnt_reg : std_logic_vector(13 downto 0);
  signal pixel_counter : std_logic_vector(13 downto 0);
  signal slovo1 : std_logic_vector (13 downto 0);
  
  signal timer_slova : std_logic_vector (19 downto 0);
  signal pixel_counter_pravi : std_logic_vector (19 downto 0);
  signal pixel_pomerac : std_logic_vector (19 downto 0);
  

begin

  -- calculate message lenght from font size
  message_lenght <= conv_std_logic_vector(MEM_SIZE/64, MEM_ADDR_WIDTH)when (font_size = 3) else -- note: some resolution with font size (32, 64)  give non integer message lenght (like 480x640 on 64 pixel font size) 480/64= 7.5
                    conv_std_logic_vector(MEM_SIZE/16, MEM_ADDR_WIDTH)when (font_size = 2) else
                    conv_std_logic_vector(MEM_SIZE/4 , MEM_ADDR_WIDTH)when (font_size = 1) else
                    conv_std_logic_vector(MEM_SIZE   , MEM_ADDR_WIDTH);
  
  graphics_lenght <= conv_std_logic_vector(MEM_SIZE*8*8, GRAPH_MEM_ADDR_WIDTH);
  
  -- removed to inputs pin
  -- direct_mode <= '0';
  -- display_mode     <= "10";  -- 01 - text mode, 10 - graphics mode, 11 - text & graphics
  
  font_size        <= x"1";
  show_frame       <= '1';
  foreground_color <= x"FFFFFF";
  background_color <= x"000000";
  frame_color      <= x"FF0000";

  clk5m_inst : ODDR2
  generic map(
    DDR_ALIGNMENT => "NONE",  -- Sets output alignment to "NONE","C0", "C1" 
    INIT => '0',              -- Sets initial state of the Q output to '0' or '1'
    SRTYPE => "SYNC"          -- Specifies "SYNC" or "ASYNC" set/reset
  )
  port map (
    Q  => pix_clock_o,       -- 1-bit output data
    C0 => pix_clock_s,       -- 1-bit clock input
    C1 => pix_clock_n,       -- 1-bit clock input
    CE => '1',               -- 1-bit clock enable input
    D0 => '1',               -- 1-bit data input (associated with C0)
    D1 => '0',               -- 1-bit data input (associated with C1)
    R  => '0',               -- 1-bit reset input
    S  => '0'                -- 1-bit set input
  );
  pix_clock_n <= not(pix_clock_s);

  -- component instantiation
  vga_top_i: vga_top
  generic map(
    RES_TYPE             => RES_TYPE,
    H_RES                => H_RES,
    V_RES                => V_RES,
    MEM_ADDR_WIDTH       => MEM_ADDR_WIDTH,
    GRAPH_MEM_ADDR_WIDTH => GRAPH_MEM_ADDR_WIDTH,
    TEXT_MEM_DATA_WIDTH  => TEXT_MEM_DATA_WIDTH,
    GRAPH_MEM_DATA_WIDTH => GRAPH_MEM_DATA_WIDTH,
    MEM_SIZE             => MEM_SIZE
  )
  port map(
    clk_i              => clk_i,
    reset_n_i          => reset_n_i,
    --
    direct_mode_i      => direct_mode_i,
    dir_red_i          => dir_red,
    dir_green_i        => dir_green,
    dir_blue_i         => dir_blue,
    dir_pixel_column_o => dir_pixel_column,
    dir_pixel_row_o    => dir_pixel_row,
    -- cfg
    display_mode_i     => display_mode_i,  -- 01 - text mode, 10 - graphics mode, 11 - text & graphics
    -- text mode interface
    text_addr_i        => char_address,
    text_data_i        => char_value,
    text_we_i          => char_we,
    -- graphics mode interface
    graph_addr_i       => pixel_address,
    graph_data_i       => pixel_value,
    graph_we_i         => pixel_we,
    -- cfg
    font_size_i        => font_size,
    show_frame_i       => show_frame,
    foreground_color_i => foreground_color,
    background_color_i => background_color,
    frame_color_i      => frame_color,
    -- vga
    vga_hsync_o        => vga_hsync_o,
    vga_vsync_o        => vga_vsync_o,
    blank_o            => blank_o,
    pix_clock_o        => pix_clock_s,
    vga_rst_n_o        => vga_rst_n_s,
    psave_o            => psave_o,
    sync_o             => sync_o,
    red_o              => red_o,
    green_o            => green_o,
    blue_o             => blue_o     
  );
  
	--mem_reg : reg
--generic map(
--		WIDTH => 14,
--		RST_INIT => 0
--	)
	--port map(
--		i_clk => pix_clock_s,
--		in_rst => vga_rst_n_s,
--		i_d => cnt_reg,
--		o_q => char_address
--	);
  -- na osnovu signala iz vga_top modula dir_pixel_column i dir_pixel_row realizovati logiku koja genereise
  --dir_red
  --dir_green
  --dir_blue
  process(dir_pixel_column)
	begin
		if(dir_pixel_column >=0 and dir_pixel_column < H_RES/8) then
			dir_red<=x"FF";
			dir_green<=x"FF";
			dir_blue<=x"FF";
		elsif (dir_pixel_column >=H_RES/8 and dir_pixel_column < (H_RES/8)*2) then
			dir_red<=x"FF";
			dir_green<=x"9D";
			dir_blue<=x"00";
		elsif (dir_pixel_column >=(H_RES/8)*2 and dir_pixel_column < (H_RES/8)*3) then
			dir_red<=x"00";
			dir_green<=x"ff";
			dir_blue<=x"f2";
		elsif (dir_pixel_column >=(H_RES/8)*3 and dir_pixel_column < (H_RES/8)*4) then
			dir_red<=x"4c";
			dir_green<=x"ff";
			dir_blue<=x"00";	
		elsif (dir_pixel_column >=(H_RES/8)*4 and dir_pixel_column < (H_RES/8)*5) then
			dir_red<=x"ff";
			dir_green<=x"00";
			dir_blue<=x"f6";
		elsif (dir_pixel_column >=(H_RES/8)*5 and dir_pixel_column < (H_RES/8)*6) then
			dir_red<=x"ff";
			dir_green<=x"00";
			dir_blue<=x"00";	
		elsif (dir_pixel_column >=(H_RES/8)*6 and dir_pixel_column < (H_RES/8)*7) then
			dir_red<=x"00";
			dir_green<=x"00";
			dir_blue<=x"ff";	
		else
			dir_red<=x"00";
			dir_green<=x"00";
			dir_blue<=x"00";	
		end if;
	end process;
  -- koristeci signale realizovati logiku koja pise po TXT_MEM
  --char_address
  --char_value
  --char_we
  --process(char_address,char_value)
 -- begin
	  
	 char_we<='1';
	--  mem_reg_o<=
	--  char_address<=conv_std_logic_vector(0,char_address ' length);
	--  char_value<=conv_std_logic_vector(1,char_value ' length);
		  
  --end process;
  -- koristeci signale realizovati logiku koja pise po GRAPH_MEM
  --pixel_address
  --pixel_value
  --pixel_we
  
   --cnt_reg <= char_address + 1 when char_address < 30*40
     --      else (others => '0');
	--cnt_reg <= char_address + 1;
	
	
	process(pix_clock_s)begin
		if(rising_edge(pix_clock_s))then
			if(pixel_counter = 1199)then
				pixel_counter <= (others => '0');
			else
				pixel_counter <= pixel_counter + 1;
			end if;
		end if;
  end process;
  
  
  
  	process(pix_clock_s,vga_rst_n_s)begin
		--if(vga_rst_n_s='0')then
			--slovo1 <= "00000000000000";
		--	slovo2 <= "00000000000001";
		--	slovo3 <= "00000000000010";
	--		slovo4 <= "00000000000011";
		--else
		
		if(rising_edge(pix_clock_s))then
			if(timer_slova = 1048574) then
				timer_slova<="00000000000000000000";
			else
				timer_slova<=timer_slova+1;
			end if;
			if(timer_slova=1048572)then
			
				if(pixel_pomerac = 9599)then
					pixel_pomerac<=(others=>'0');
				else
					pixel_pomerac<=pixel_pomerac+1;
				end if;
			
				if(slovo1 = 1196)then
					slovo1 <= (others => '0');
				else
					slovo1 <= slovo1 + 1;
				end if;
				
				--if(slovo2 = 1197)then
				--	slovo2 <= "00000000000001";
				--else
				--	slovo2 <= slovo2 + 1;
			--	end if;
			--	if(slovo3 = 1198)then
			--		slovo3 <= "00000000000010";
			--	else
			--		slovo3 <= slovo3 + 1;
				--end if;
			--	if(slovo4 = 1199)then
			--		slovo4 <= "00000000000011";
			--	else
			--		slovo4 <= slovo4 + 1;
				end if;
			--end if;
	--	end if;
		end if;
  end process;
  

  
  
  
  
	process(pix_clock_s)begin
		if(rising_edge(pix_clock_s))then
			if(pixel_counter_pravi = 9599)then
				pixel_counter_pravi <= (others => '0');
			else
				pixel_counter_pravi <= pixel_counter_pravi + 1;
			end if;
		end if;
  end process;
	
	process(char_address,pixel_counter) begin
		if(pixel_counter = slovo1)then
			char_address<=pixel_counter;
			char_value <= conv_std_logic_vector(2,6);--B
			
		elsif(pixel_counter=slovo1+1) then
			char_address<=pixel_counter;
			char_value <= conv_std_logic_vector(21,6);--U
		elsif(pixel_counter=slovo1+2) then
			char_address<=pixel_counter;
			char_value <= conv_std_logic_vector(18,6);--R
		elsif(pixel_counter=slovo1+3) then
			char_address<=pixel_counter;
			char_value <= conv_std_logic_vector(26,6);--Z
		else
			char_address<=pixel_counter;
			char_value <= conv_std_logic_vector(32,6);--razmak
		end if;
	end process;
	
	pixel_we <= '1';
	
	
	process(pixel_counter_pravi,pixel_pomerac) begin
		if(pixel_counter_pravi = pixel_pomerac)then
			pixel_address<=pixel_counter_pravi;
			pixel_value <= x"FFFFFFFF";
			
		elsif(pixel_counter_pravi=pixel_pomerac+20) then
			pixel_address<=pixel_counter_pravi;
			pixel_value <= x"FFFFFFFF";
		elsif(pixel_counter_pravi=pixel_pomerac+40) then
			pixel_address<=pixel_counter_pravi;
			pixel_value <= x"FFFFFFFF";
		elsif(pixel_counter_pravi=pixel_pomerac+60) then
			pixel_address<=pixel_counter_pravi;
			pixel_value <= x"FFFFFFFF";
		elsif(pixel_counter_pravi=pixel_pomerac+80) then
			pixel_address<=pixel_counter_pravi;
			pixel_value <= x"FFFFFFFF";
		elsif(pixel_counter_pravi=pixel_pomerac+100) then
			pixel_address<=pixel_counter_pravi;
			pixel_value <= x"FFFFFFFF";
		elsif(pixel_counter_pravi=pixel_pomerac+120) then
			pixel_address<=pixel_counter_pravi;
			pixel_value <= x"FFFFFFFF";
		elsif(pixel_counter_pravi=pixel_pomerac+140) then
			pixel_address<=pixel_counter_pravi;
			pixel_value <= x"FFFFFFFF";
		elsif(pixel_counter_pravi=pixel_pomerac+160) then
			pixel_address<=pixel_counter_pravi;
			pixel_value <= x"FFFFFFFF";
		elsif(pixel_counter_pravi=pixel_pomerac+180) then
			pixel_address<=pixel_counter_pravi;
			pixel_value <= x"FFFFFFFF";
		elsif(pixel_counter_pravi=pixel_pomerac+200) then
			pixel_address<=pixel_counter_pravi;
			pixel_value <= x"FFFFFFFF";
		elsif(pixel_counter_pravi=pixel_pomerac+220) then
			pixel_address<=pixel_counter_pravi;
			pixel_value <= x"FFFFFFFF";
		elsif(pixel_counter_pravi=pixel_pomerac+240) then
			pixel_address<=pixel_counter_pravi;
			pixel_value <= x"FFFFFFFF";
		elsif(pixel_counter_pravi=pixel_pomerac+260) then
			pixel_address<=pixel_counter_pravi;
			pixel_value <= x"FFFFFFFF";
		elsif(pixel_counter_pravi=pixel_pomerac+280) then
			pixel_address<=pixel_counter_pravi;
			pixel_value <= x"FFFFFFFF";
		elsif(pixel_counter_pravi=pixel_pomerac+300) then
			pixel_address<=pixel_counter_pravi;
			pixel_value <= x"FFFFFFFF";
		elsif(pixel_counter_pravi=pixel_pomerac+320) then
			pixel_address<=pixel_counter_pravi;
			pixel_value <= x"FFFFFFFF";
		elsif(pixel_counter_pravi=pixel_pomerac+340) then
			pixel_address<=pixel_counter_pravi;
			pixel_value <= x"FFFFFFFF";
		elsif(pixel_counter_pravi=pixel_pomerac+360) then
			pixel_address<=pixel_counter_pravi;
			pixel_value <= x"FFFFFFFF";
		elsif(pixel_counter_pravi=pixel_pomerac+380) then
			pixel_address<=pixel_counter_pravi;
			pixel_value <= x"FFFFFFFF";
		elsif(pixel_counter_pravi=pixel_pomerac+400) then
			pixel_address<=pixel_counter_pravi;
			pixel_value <= x"FFFFFFFF";
		else
			pixel_address<=pixel_counter_pravi;
			pixel_value <= x"00000000";
		end if;
	end process;
	
	
	
	
  
end rtl;