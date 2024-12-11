library IEEE, mylib;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_MISC.ALL;
use ieee.numeric_std.all;

use mylib.defBCT.all;

entity SpillGateGenerator is
  port(
    rst                 : in std_logic;
    clk                 : in std_logic; -- 100 MHz is expected

    -- Input --
    p3timingIn          : in std_logic;

    -- Output --
    spillGateOut        : out std_logic;

    -- Local bus --
    addrLocalBus	      : in LocalAddressType;
    dataLocalBusIn	    : in LocalBusInType;
    dataLocalBusOut	    : out LocalBusOutType;
    reLocalBus		      : in std_logic;
    weLocalBus		      : in std_logic;
    readyLocalBus	      : out std_logic

  );
end SpillGateGenerator;

architecture RTL of SpillGateGenerator is
  -- signal declaration --
  signal sync_reset   : std_logic;

  signal clk_1u       : std_logic_vector(7 downto 0);
  signal en_1u        : std_logic;

  signal p3_sync      : std_logic;
  signal p3_one_shot  : std_logic;
  signal reg_p3       : std_logic;
  signal delay_gate, spill_gate : std_logic;
  signal delay_count, spill_count : std_logic_vector(31 downto 0);

  -- local bus --
  signal reg_delay_count, reg_spill_count : std_logic_vector(31 downto 0);
  signal state_lbus	: BusProcessType;

  -- Local Address  -------------------------------------------------------
  constant kDelayCount          : LocalAddressType := x"000"; -- W/R, [31:0],
  constant kSpillCount          : LocalAddressType := x"010"; -- W/R, [31:0],

  -- debug ----------------------------------------------------------------
  attribute mark_debug  : string;
  attribute mark_debug of clk_1u        : signal is "false";
  attribute mark_debug of en_1u         : signal is "false";
  attribute mark_debug of p3_one_shot   : signal is "false";
  attribute mark_debug of reg_p3        : signal is "false";
  attribute mark_debug of delay_count   : signal is "false";
  attribute mark_debug of delay_gate    : signal is "false";
  attribute mark_debug of spill_count   : signal is "false";
  attribute mark_debug of spill_gate    : signal is "false";

begin
  -- ============================== Body ====================================


  spillGateOut  <= spill_gate;

  u_100c : process(clk)
  begin
    if(clk'event and clk = '1') then
      if(unsigned(clk_1u) = 99) then
        clk_1u  <= (others => '0');
        en_1u   <= '1';
      else
        clk_1u <= std_logic_vector(unsigned(clk_1u) + 1);
        en_1u   <= '0';
      end if;
    end if;
  end process;

  u_sync : entity mylib.synchronizer port map(clk, p3timingIn, p3_sync);
  u_edge : entity mylib.EdgeDetector port map(clk, p3_sync, p3_one_shot);

  u_gate : process(clk)
  begin
    if(clk'event and clk = '1') then
      if(p3_one_shot = '1') then
        reg_p3  <= '1';
      elsif(delay_gate = '1') then
        reg_p3  <= '0';
      end if;

      if(reg_p3 = '1' and en_1u = '1') then
        delay_gate  <= '1';
      elsif(spill_gate = '1') then
        delay_gate  <= '0';
      end if;

      if(en_1u = '1') then
        if(delay_gate = '1') then
          delay_count   <=  std_logic_vector(unsigned(delay_count) +1);
        else
          delay_count   <= (others => '0');
        end if;

        if(delay_count = reg_delay_count) then
          spill_gate  <= '1';
        elsif(spill_count = reg_spill_count) then
          spill_gate  <= '0';
        elsif(reg_p3 = '1') then
        spill_gate  <= '0';
        end if;

        if(spill_gate = '1') then
          spill_count <= std_logic_vector(unsigned(spill_count) +1);
        else
          spill_count <= (others => '0');
        end if;
      end if;
    end if;
  end process;

  -- Local bus process ------------------------------------------------
  u_BusProcess : process(clk)
  begin
    if(clk'event and clk = '1') then
      if(sync_reset = '1') then
        reg_delay_count   <= X"000003E8";
        reg_spill_count   <= X"000003E8";

        dataLocalBusOut     <= x"00";
        readyLocalBus		    <= '0';
        state_lbus	        <= Init;
      else
        case state_lbus is
          when Init =>
            dataLocalBusOut     <= x"00";
            readyLocalBus		    <= '0';
            state_lbus		      <= Idle;

          when Idle =>
            readyLocalBus	<= '0';
            if(weLocalBus = '1' or reLocalBus = '1') then
              state_lbus	<= Connect;
            end if;

          when Connect =>
            if(weLocalBus = '1') then
              state_lbus	<= Write;
            else
              state_lbus	<= Read;
            end if;

          when Write =>
            case addrLocalBus(kNonMultiByte'range) is
              when kDelayCount(kNonMultiByte'range) =>
                if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                  reg_delay_count(7 downto 0)	  <= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                  reg_delay_count(15 downto 8)	  <= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k3rdbyte) then
                  reg_delay_count(23 downto 16)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k4thbyte) then
                  reg_delay_count(31 downto 24)	<= dataLocalBusIn;
                else
                  reg_delay_count(7 downto 0)	<= dataLocalBusIn;
                end if;
                state_lbus	<= Done;

              when kSpillCount(kNonMultiByte'range) =>
                if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                  reg_spill_count(7 downto 0)	  <= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                  reg_spill_count(15 downto 8)	  <= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k3rdbyte) then
                  reg_spill_count(23 downto 16)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k4thbyte) then
                  reg_spill_count(31 downto 24)	<= dataLocalBusIn;
                else
                  reg_spill_count(7 downto 0)	<= dataLocalBusIn;
                end if;
                state_lbus	<= Done;

              when others =>
                state_lbus	<= Done;
            end case;

          when Read =>
            case addrLocalBus(kNonMultiByte'range) is
              when kDelayCount(kNonMultiByte'range) =>
                if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                  dataLocalBusOut <= reg_delay_count(7 downto 0)	 ;
                elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                  dataLocalBusOut <= reg_delay_count(15 downto 8)	 ;
                elsif( addrLocalBus(kMultiByte'range) = k3rdbyte) then
                  dataLocalBusOut <= reg_delay_count(23 downto 16);
                elsif( addrLocalBus(kMultiByte'range) = k4thbyte) then
                  dataLocalBusOut <= reg_delay_count(31 downto 24);
                else
                  dataLocalBusOut <= reg_delay_count(7 downto 0)	 ;
                end if;
                state_lbus	<= Done;

              when kSpillCount(kNonMultiByte'range) =>
                if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                  dataLocalBusOut <= reg_spill_count(7 downto 0)	 ;
                elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                  dataLocalBusOut <= reg_spill_count(15 downto 8)	 ;
                elsif( addrLocalBus(kMultiByte'range) = k3rdbyte) then
                  dataLocalBusOut <= reg_spill_count(23 downto 16);
                elsif( addrLocalBus(kMultiByte'range) = k4thbyte) then
                  dataLocalBusOut <= reg_spill_count(31 downto 24);
                else
                  dataLocalBusOut <= reg_spill_count(7 downto 0)	 ;
                end if;
                state_lbus	<= Done;

              when others =>
                state_lbus	<= Done;
            end case;

          when Done =>
            readyLocalBus	<= '1';
            if(weLocalBus = '0' and reLocalBus = '0') then
              state_lbus	<= Idle;
            end if;

          -- probably this is error --
          when others =>
            state_lbus	<= Init;
        end case;
      end if;
    end if;
  end process u_BusProcess;


  -- Reset sequence --
  u_reset_gen_sys   : entity mylib.ResetGen
    port map(rst, clk, sync_reset);


end RTL;