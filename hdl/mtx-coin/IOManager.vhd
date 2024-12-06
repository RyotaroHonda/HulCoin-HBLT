library IEEE, mylib;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.math_real.all;

use mylib.defBCT.all;
use mylib.defIOManager.all;

entity IOManager is
  generic(
    kNumExtIO           : integer:= 4;
    kNumIntI            : integer:= 16
  );
  port(
    rst	                : in std_logic;
    clk	                : in std_logic;

    -- Ext Output
    intInput            : in std_logic_vector(kNumIntI-1 downto 0);
    extOutput           : out std_logic_vector(kNumExtIO-1 downto 0);

    -- Local bus --
    addrLocalBus        : in LocalAddressType;
    dataLocalBusIn      : in LocalBusInType;
    dataLocalBusOut	    : out LocalBusOutType;
    reLocalBus          : in std_logic;
    weLocalBus          : in std_logic;
    readyLocalBus	      : out std_logic
    );
end IOManager;

architecture RTL of IOManager is

  -- System --
  signal sync_reset           : std_logic;

  -- internal signal declaration ----------------------------------------
  constant kWidthIntIn : integer:= integer(ceil(log2(real(kNumIntI)))) +1;
  type kIntInReg is array(integer range kNumExtIO-1 downto 0)
    of std_logic_vector(kWidthIntIn-1 downto 0);

  signal reg_intin_sel  : kIntInReg;

  signal state_lbus	: BusProcessType;

-- =============================== body ===============================
begin

  -- External output --
  gen_out : for i in 0 to kNumExtIO-1 generate
    extOutput(i)  <= '0' when(reg_intin_sel(i)(kWidthIntIn-1) = '1') else intInput(to_integer(unsigned(reg_intin_sel(i)(kWidthIntIn-1 downto 0))));
  end generate;

  u_BusProcess : process(clk)
  begin
    if(clk'event and clk = '1') then
      if(sync_reset = '1') then
        reg_intin_sel(0)  <= (others => '0');
        reg_intin_sel(1)  <= (others => '0');
        reg_intin_sel(2)  <= (others => '0');
        reg_intin_sel(3)  <= (others => '0');

        state_lbus	<= Init;
      else
        case state_lbus is
          when Init =>
            dataLocalBusOut   <= x"00";
            readyLocalBus		  <= '0';

            reg_intin_sel(0)  <= (others => '0');
            reg_intin_sel(1)  <= (others => '0');
            reg_intin_sel(2)  <= (others => '0');
            reg_intin_sel(3)  <= (others => '0');

            state_lbus		<= Idle;

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
              when kSelIntIn0(kNonMultiByte'range) =>
                reg_intin_sel(0)  <= dataLocalBusIn(kWidthIntIn-1 downto 0);
              when kSelIntIn1(kNonMultiByte'range) =>
                reg_intin_sel(1)  <= dataLocalBusIn(kWidthIntIn-1 downto 0);
              when kSelIntIn2(kNonMultiByte'range) =>
                reg_intin_sel(2)  <= dataLocalBusIn(kWidthIntIn-1 downto 0);
              when kSelIntIn3(kNonMultiByte'range) =>
                reg_intin_sel(3)  <= dataLocalBusIn(kWidthIntIn-1 downto 0);

              when others => null;
            end case;
            state_lbus	<= Done;

          when Read =>
            case addrLocalBus(kNonMultiByte'range) is
              when kSelIntIn0(kNonMultiByte'range) =>
                dataLocalBusOut  <= (reg_intin_sel(0)'range => reg_intin_sel(0), others => '0');
              when kSelIntIn1(kNonMultiByte'range) =>
                dataLocalBusOut  <= (reg_intin_sel(1)'range => reg_intin_sel(1), others => '0');
              when kSelIntIn2(kNonMultiByte'range) =>
                dataLocalBusOut  <= (reg_intin_sel(2)'range => reg_intin_sel(2), others => '0');
              when kSelIntIn3(kNonMultiByte'range) =>
                dataLocalBusOut  <= (reg_intin_sel(3)'range => reg_intin_sel(3), others => '0');

              when others =>
                dataLocalBusOut <= x"ff";
            end case;
            state_lbus	<= Done;

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

