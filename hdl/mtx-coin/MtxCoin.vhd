library IEEE, mylib;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_MISC.ALL;
use ieee.numeric_std.all;

use mylib.defBCT.all;

entity MtxCoin is
  generic(
    kNumTele    : integer:= 3;
    kNumAc      : integer:= 4;
    kNumPad     : integer:= 32;
    kNumOut     : integer:= 64;
    kNumProbe   : integer:= 16
  );
  port(
    rst                 : in std_logic;
    clk                 : in std_logic;
    clkFast             : in std_logic;

    -- Input --
    sigInTelescope      : in std_logic_vector(kNumTele downto 1);
    sigInAc             : in std_logic_vector(kNumAc downto 1);
    sigInPad            : in std_logic_vector(kNumPad downto 1);
    trgFee              : in std_logic;
    miniScinti          : in std_logic;

    -- Output --
    sigOut              : out std_logic_vector(kNumOut downto 1);
    probeOut            : out std_logic_vector(kNumProbe-1 downto 0);

    -- Local bus --
    addrLocalBus	      : in LocalAddressType;
    dataLocalBusIn	    : in LocalBusInType;
    dataLocalBusOut	    : out LocalBusOutType;
    reLocalBus		      : in std_logic;
    weLocalBus		      : in std_logic;
    readyLocalBus	      : out std_logic

  );
end MtxCoin;

architecture RTL of MtxCoin is
  -- signal declaration --
  signal sync_reset   : std_logic;

  -- layer-1 --
  signal sync_tele    : std_logic_vector(sigInTelescope'range);
  signal dwg_out_tele : std_logic_vector(sigInTelescope'range);
  signal masked_tele  : std_logic_vector(sigInTelescope'range);
  signal coin_tele    : std_logic_vector(4 downto 1);

  signal sync_ac      : std_logic_vector(sigInAc'range);
  signal dwg_out_ac   : std_logic_vector(sigInAc'range);
  signal or_ac        : std_logic;

  signal sync_pad     : std_logic_vector(sigInPad'range);
  signal sync_pad_delay : std_logic_vector(sigInPad'range);
  signal dwg_out_pad  : std_logic_vector(sigInPad'range);
  signal or_pad       : std_logic_vector(2 downto 1);
  signal coin_pad     : std_logic;

  -- layer-2 --
  signal masked_trg   : std_logic;
  signal masked_ac    : std_logic;

  signal dwg_out_trg, dwg_out_mtrg  : std_logic;
  signal dwg_out_orac, dwg_out_morac    : std_logic;

  signal raw_results      : std_logic_vector(sigOut'range);
  signal dwg_out_results  : std_logic_vector(sigOut'range);

  -- probe --
  signal reg_probe_out    : std_logic_vector(probeOut'range);

  -- local bus --
  signal reg_dwg_tele, reg_dwg_ac, reg_dwg_pad, reg_dwg_trg, reg_dwg_orac : std_logic_vector(63 downto 0);
  signal reg_coin_tele  : std_logic_vector(2 downto 0);
  signal reg_ctrl       : std_logic_vector(1 downto 0);
  signal state_lbus	: BusProcessType;

  -- Local Address  -------------------------------------------------------
  constant kDwgTele             : LocalAddressType := x"000"; -- W/R, [63:0],
  constant kDwgAc               : LocalAddressType := x"010"; -- W/R, [63:0],
  constant kDwgPad              : LocalAddressType := x"020"; -- W/R, [63:0],
  constant kDwgTrg              : LocalAddressType := x"030"; -- W/R, [63:0],
  constant kDwgOrAc             : LocalAddressType := x"040"; -- W/R, [63:0],
  constant kCoinTele            : LocalAddressType := x"050"; -- W/R, [2:0],
  constant kCtrl                : LocalAddressType := x"060"; -- W/R, [1:0],

begin
  -- ============================== Body ====================================

  -- ------------------------------------------------------------------------
  --                           Fast Clock Domain
  -- ------------------------------------------------------------------------

  -- Layer-1 ----------------------------------------------------------------
  -- input process --
  gen_tele : for i in 1 to kNumTele generate
  begin
    u_sync : entity mylib.synchronizer port map(clkFast, sigInTelescope(i), sync_tele(i));
    u_dwg  : entity mylib.DWGenerator  port map(clkFast, sync_tele(i), reg_dwg_tele, dwg_out_tele(i));
  end generate;

  gen_ac : for i in 1 to kNumAc generate
  begin
    u_sync : entity mylib.synchronizer port map(clkFast, sigInAc(i), sync_ac(i));
    u_dwg  : entity mylib.DWGenerator  port map(clkFast, sync_ac(i), reg_dwg_ac, dwg_out_ac(i));
  end generate;

  gen_pad : for i in 1 to kNumPad generate
  begin
    u_sync : entity mylib.synchronizer port map(clkFast, sigInPad(i), sync_pad(i));
    --u_delay : entity mylib.DelayGen generic map(25) port map(clkFast, sync_pad(i), sync_pad_delay(i));
    u_dwg  : entity mylib.DWGenerator  port map(clkFast, sync_pad(i), reg_dwg_pad, dwg_out_pad(i));
  end generate;

  -- Telescope --
  masked_tele   <= dwg_out_tele or reg_coin_tele;

  coin_tele(1)  <= masked_tele(1) and masked_tele(2) and masked_tele(3);
  coin_tele(2)  <= dwg_out_tele(1) and dwg_out_tele(2);
  coin_tele(3)  <= dwg_out_tele(2) and dwg_out_tele(3);
  coin_tele(4)  <= dwg_out_tele(1) and dwg_out_tele(3);

  -- AC --
  or_ac         <= '1' when(unsigned(dwg_out_ac) /= 0) else '0';

  -- Pad --
  or_pad(1)     <= '1' when(unsigned(dwg_out_pad(16 downto 1))  /= 0) else '0';
  or_pad(2)     <= '1' when(unsigned(dwg_out_pad(32 downto 17)) /= 0) else '0';
  coin_pad      <= or_pad(1) and or_pad(2);

  -- Layer-2 ----------------------------------------------------------------
  u_dwg_trg :  entity mylib.DWGenerator  port map(clkFast, coin_tele(1), reg_dwg_trg,  dwg_out_trg);
  u_dwg_ac :   entity mylib.DWGenerator  port map(clkFast, or_ac,        reg_dwg_orac, dwg_out_orac);

  dwg_out_mtrg   <= reg_ctrl(0) or dwg_out_trg;
  dwg_out_morac  <= reg_ctrl(1) or dwg_out_orac;

  raw_results(1)    <= coin_tele(1);
  raw_results(2)    <= coin_tele(2);
  raw_results(3)    <= coin_tele(3);
  raw_results(4)    <= coin_tele(4);
  raw_results(5)    <= sigInTelescope(1);
  raw_results(6)    <= sigInTelescope(2);
  raw_results(7)    <= sigInTelescope(3);
  raw_results(8)    <= or_pad(1);
  raw_results(9)    <= or_pad(2);
  raw_results(10)   <= coin_pad;
  raw_results(11)   <= coin_pad and dwg_out_trg;
  gen_coin_mppc : for i in 1 to kNumPad generate
  begin
    raw_results(i+11)   <= dwg_out_pad(i) and dwg_out_mtrg and dwg_out_morac;
  end generate;

  gen_coin_ac : for i in 1 to kNumAc generate
  begin
    raw_results(i+43)   <= dwg_out_ac(i) and dwg_out_mtrg;
  end generate;

  raw_results(48)   <= or_ac;
  raw_results(49)   <= or_ac and dwg_out_trg;
  raw_results(50)   <= or_ac and or_pad(1);
  raw_results(51)   <= or_ac and or_pad(2);
  raw_results(52)   <= or_ac and coin_pad;
  raw_results(53)   <= coin_pad and dwg_out_trg and dwg_out_orac;

  raw_results(54)   <= dwg_out_trg and or_reduce(dwg_out_pad(9 downto 8)) and or_reduce(dwg_out_pad(25 downto 24));
  raw_results(55)   <= dwg_out_trg and or_reduce(dwg_out_pad(11 downto 6)) and or_reduce(dwg_out_pad(27 downto 22));
  raw_results(56)   <= dwg_out_trg and or_reduce(dwg_out_pad(13 downto 4)) and or_reduce(dwg_out_pad(29 downto 20));
  raw_results(57)   <= dwg_out_trg and or_reduce(dwg_out_pad(15 downto 2)) and or_reduce(dwg_out_pad(31 downto 18));

  raw_results(58)   <= dwg_out_trg and or_reduce(dwg_out_pad(9 downto 8))  and or_reduce(dwg_out_pad(25 downto 24)) and dwg_out_orac;
  raw_results(59)   <= dwg_out_trg and or_reduce(dwg_out_pad(11 downto 6)) and or_reduce(dwg_out_pad(27 downto 22)) and dwg_out_orac;
  raw_results(60)   <= dwg_out_trg and or_reduce(dwg_out_pad(13 downto 4)) and or_reduce(dwg_out_pad(29 downto 20)) and dwg_out_orac;
  raw_results(61)   <= dwg_out_trg and or_reduce(dwg_out_pad(15 downto 2)) and or_reduce(dwg_out_pad(31 downto 18)) and dwg_out_orac;

  raw_results(62)   <= trgFee;
  raw_results(63)   <= miniScinti;
  raw_results(64)   <= '0';

  -- Generate 20 ns width to output --
  gen_out : for i in 1 to kNumOut generate
  begin
    u_dwg : entity mylib.DWGenerator port map(clkFast, raw_results(i), X"FFC0000000000000", dwg_out_results(i));
  end generate;

  sigOut  <= dwg_out_results;

  -- Probe output ---------------------------------------------------
  reg_probe_out(0)   <= '0';
  reg_probe_out(1)   <= dwg_out_tele(1);
  reg_probe_out(2)   <= dwg_out_tele(2);
  reg_probe_out(3)   <= dwg_out_tele(3);
  reg_probe_out(4)   <= or_ac;
  reg_probe_out(5)   <= coin_pad;
  reg_probe_out(6)   <= dwg_out_trg;
  reg_probe_out(7)   <= dwg_out_orac;
  reg_probe_out(8)   <= coin_pad and dwg_out_trg;
  reg_probe_out(9)   <= or_ac and dwg_out_trg;
  reg_probe_out(10)  <= or_ac and coin_pad;
  reg_probe_out(11)  <= coin_pad and dwg_out_trg and dwg_out_orac;
  reg_probe_out(12)  <= '0';
  reg_probe_out(13)  <= '0';
  reg_probe_out(14)  <= '0';
  reg_probe_out(15)  <= '0';

  process(clkFast)
  begin
    if(clkFast'event and clkFast = '1') then
      probeOut  <= reg_probe_out;
    end if;
  end process;

  -- ------------------------------------------------------------------------
  --                           System Clock Domain
  -- ------------------------------------------------------------------------

  -- Local bus process ------------------------------------------------
  u_BusProcess : process(clk)
  begin
    if(clk'event and clk = '1') then
      if(sync_reset = '1') then
        reg_dwg_tele      <= (others => '0');
        reg_dwg_ac        <= (others => '0');
        reg_dwg_pad       <= (others => '0');

        reg_dwg_trg       <= (others => '0');
        reg_dwg_orac      <= (others => '0');

        reg_coin_tele     <= (others => '0');
        reg_ctrl          <= (others => '0');

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
              when kDwgTele(kNonMultiByte'range) =>
                if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                  reg_dwg_tele(7 downto 0)	  <= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                  reg_dwg_tele(15 downto 8)	  <= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k3rdbyte) then
                  reg_dwg_tele(23 downto 16)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k4thbyte) then
                  reg_dwg_tele(31 downto 24)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k5thbyte) then
                  reg_dwg_tele(39 downto 32)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k6thbyte) then
                  reg_dwg_tele(47 downto 40)  <= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k7thbyte) then
                  reg_dwg_tele(55 downto 48)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k8thbyte) then
                  reg_dwg_tele(63 downto 56)	<= dataLocalBusIn;
                else
                  reg_dwg_tele(7 downto 0)	<= dataLocalBusIn;
                end if;
                state_lbus	<= Done;

              when kDwgAc(kNonMultiByte'range) =>
                if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                  reg_dwg_ac(7 downto 0)	  <= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                  reg_dwg_ac(15 downto 8)	  <= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k3rdbyte) then
                  reg_dwg_ac(23 downto 16)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k4thbyte) then
                  reg_dwg_ac(31 downto 24)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k5thbyte) then
                  reg_dwg_ac(39 downto 32)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k6thbyte) then
                  reg_dwg_ac(47 downto 40)  <= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k7thbyte) then
                  reg_dwg_ac(55 downto 48)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k8thbyte) then
                  reg_dwg_ac(63 downto 56)	<= dataLocalBusIn;
                else
                  reg_dwg_ac(7 downto 0)	<= dataLocalBusIn;
                end if;
                state_lbus	<= Done;

              --
              when kDwgPad(kNonMultiByte'range) =>
                if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                  reg_dwg_pad(7 downto 0)	  <= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                  reg_dwg_pad(15 downto 8)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k3rdbyte) then
                  reg_dwg_pad(23 downto 16)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k4thbyte) then
                  reg_dwg_pad(31 downto 24)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k5thbyte) then
                  reg_dwg_pad(39 downto 32)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k6thbyte) then
                  reg_dwg_pad(47 downto 40) <= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k7thbyte) then
                  reg_dwg_pad(55 downto 48)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k8thbyte) then
                  reg_dwg_pad(63 downto 56)	<= dataLocalBusIn;
                else
                  reg_dwg_pad(7 downto 0)	<= dataLocalBusIn;
                end if;
                state_lbus	<= Done;

              when kDwgTrg(kNonMultiByte'range) =>
                if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                  reg_dwg_trg(7 downto 0)	  <= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                  reg_dwg_trg(15 downto 8)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k3rdbyte) then
                  reg_dwg_trg(23 downto 16)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k4thbyte) then
                  reg_dwg_trg(31 downto 24)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k5thbyte) then
                  reg_dwg_trg(39 downto 32)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k6thbyte) then
                  reg_dwg_trg(47 downto 40) <= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k7thbyte) then
                  reg_dwg_trg(55 downto 48)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k8thbyte) then
                  reg_dwg_trg(63 downto 56)	<= dataLocalBusIn;
                else
                  reg_dwg_trg(7 downto 0)	<= dataLocalBusIn;
                end if;
                state_lbus	<= Done;

              --
              when kDwgOrAc(kNonMultiByte'range) =>
                if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                  reg_dwg_orac(7 downto 0)	  <= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                  reg_dwg_orac(15 downto 8)	  <= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k3rdbyte) then
                  reg_dwg_orac(23 downto 16)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k4thbyte) then
                  reg_dwg_orac(31 downto 24)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k5thbyte) then
                  reg_dwg_orac(39 downto 32)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k6thbyte) then
                  reg_dwg_orac(47 downto 40)  <= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k7thbyte) then
                  reg_dwg_orac(55 downto 48)	<= dataLocalBusIn;
                elsif( addrLocalBus(kMultiByte'range) = k8thbyte) then
                  reg_dwg_orac(63 downto 56)	<= dataLocalBusIn;
                else
                  reg_dwg_orac(7 downto 0)	<= dataLocalBusIn;
                end if;
                state_lbus	<= Done;

              when kCoinTele(kNonMultiByte'range) =>
                reg_coin_tele   <= dataLocalBusIn(reg_coin_tele'range);
                state_lbus	<= Done;

              when kCtrl(kNonMultiByte'range) =>
                reg_ctrl   <= dataLocalBusIn(reg_ctrl'range);
                state_lbus	<= Done;

              when others =>
                state_lbus	<= Done;
            end case;

          when Read =>
            case addrLocalBus(kNonMultiByte'range) is
              when kDwgTele(kNonMultiByte'range) =>
                if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                  dataLocalBusOut <= reg_dwg_tele(7 downto 0)	 ;
                elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                  dataLocalBusOut <= reg_dwg_tele(15 downto 8)	 ;
                elsif( addrLocalBus(kMultiByte'range) = k3rdbyte) then
                  dataLocalBusOut <= reg_dwg_tele(23 downto 16);
                elsif( addrLocalBus(kMultiByte'range) = k4thbyte) then
                  dataLocalBusOut <= reg_dwg_tele(31 downto 24);
                elsif( addrLocalBus(kMultiByte'range) = k5thbyte) then
                  dataLocalBusOut <= reg_dwg_tele(39 downto 32);
                elsif( addrLocalBus(kMultiByte'range) = k6thbyte) then
                  dataLocalBusOut <= reg_dwg_tele(47 downto 40) ;
                elsif( addrLocalBus(kMultiByte'range) = k7thbyte) then
                  dataLocalBusOut <= reg_dwg_tele(55 downto 48);
                elsif( addrLocalBus(kMultiByte'range) = k8thbyte) then
                  dataLocalBusOut <= reg_dwg_tele(63 downto 56);
                else
                  dataLocalBusOut <= reg_dwg_tele(7 downto 0)	 ;
                end if;
                state_lbus	<= Done;

              when kDwgAc(kNonMultiByte'range) =>
                if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                  dataLocalBusOut <= reg_dwg_ac(7 downto 0)	 ;
                elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                  dataLocalBusOut <= reg_dwg_ac(15 downto 8)	 ;
                elsif( addrLocalBus(kMultiByte'range) = k3rdbyte) then
                  dataLocalBusOut <= reg_dwg_ac(23 downto 16);
                elsif( addrLocalBus(kMultiByte'range) = k4thbyte) then
                  dataLocalBusOut <= reg_dwg_ac(31 downto 24);
                elsif( addrLocalBus(kMultiByte'range) = k5thbyte) then
                  dataLocalBusOut <= reg_dwg_ac(39 downto 32);
                elsif( addrLocalBus(kMultiByte'range) = k6thbyte) then
                  dataLocalBusOut <= reg_dwg_ac(47 downto 40) ;
                elsif( addrLocalBus(kMultiByte'range) = k7thbyte) then
                  dataLocalBusOut <= reg_dwg_ac(55 downto 48);
                elsif( addrLocalBus(kMultiByte'range) = k8thbyte) then
                  dataLocalBusOut <= reg_dwg_ac(63 downto 56);
                else
                  dataLocalBusOut <= reg_dwg_ac(7 downto 0)	 ;
                end if;
                state_lbus	<= Done;

              --
              when kDwgPad(kNonMultiByte'range) =>
                if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                  dataLocalBusOut <= reg_dwg_pad(7 downto 0)	 ;
                elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                  dataLocalBusOut <= reg_dwg_pad(15 downto 8);
                elsif( addrLocalBus(kMultiByte'range) = k3rdbyte) then
                  dataLocalBusOut <= reg_dwg_pad(23 downto 16);
                elsif( addrLocalBus(kMultiByte'range) = k4thbyte) then
                  dataLocalBusOut <= reg_dwg_pad(31 downto 24);
                elsif( addrLocalBus(kMultiByte'range) = k5thbyte) then
                  dataLocalBusOut <= reg_dwg_pad(39 downto 32);
                elsif( addrLocalBus(kMultiByte'range) = k6thbyte) then
                  dataLocalBusOut <= reg_dwg_pad(47 downto 40);
                elsif( addrLocalBus(kMultiByte'range) = k7thbyte) then
                  dataLocalBusOut <= reg_dwg_pad(55 downto 48);
                elsif( addrLocalBus(kMultiByte'range) = k8thbyte) then
                  dataLocalBusOut <= reg_dwg_pad(63 downto 56);
                else
                  dataLocalBusOut <= reg_dwg_pad(7 downto 0)	 ;
                end if;
                state_lbus	<= Done;

              when kDwgTrg(kNonMultiByte'range) =>
                if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                  dataLocalBusOut <= reg_dwg_trg(7 downto 0)	 ;
                elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                  dataLocalBusOut <= reg_dwg_trg(15 downto 8);
                elsif( addrLocalBus(kMultiByte'range) = k3rdbyte) then
                  dataLocalBusOut <= reg_dwg_trg(23 downto 16);
                elsif( addrLocalBus(kMultiByte'range) = k4thbyte) then
                  dataLocalBusOut <= reg_dwg_trg(31 downto 24);
                elsif( addrLocalBus(kMultiByte'range) = k5thbyte) then
                  dataLocalBusOut <= reg_dwg_trg(39 downto 32);
                elsif( addrLocalBus(kMultiByte'range) = k6thbyte) then
                  dataLocalBusOut <= reg_dwg_trg(47 downto 40);
                elsif( addrLocalBus(kMultiByte'range) = k7thbyte) then
                  dataLocalBusOut <= reg_dwg_trg(55 downto 48);
                elsif( addrLocalBus(kMultiByte'range) = k8thbyte) then
                  dataLocalBusOut <= reg_dwg_trg(63 downto 56);
                else
                  dataLocalBusOut <= reg_dwg_trg(7 downto 0)	 ;
                end if;
                state_lbus	<= Done;

              --
              when kDwgOrAc(kNonMultiByte'range) =>
                if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                  dataLocalBusOut <= reg_dwg_orac(7 downto 0)	 ;
                elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                  dataLocalBusOut <= reg_dwg_orac(15 downto 8)	 ;
                elsif( addrLocalBus(kMultiByte'range) = k3rdbyte) then
                  dataLocalBusOut <= reg_dwg_orac(23 downto 16);
                elsif( addrLocalBus(kMultiByte'range) = k4thbyte) then
                  dataLocalBusOut <= reg_dwg_orac(31 downto 24);
                elsif( addrLocalBus(kMultiByte'range) = k5thbyte) then
                  dataLocalBusOut <= reg_dwg_orac(39 downto 32);
                elsif( addrLocalBus(kMultiByte'range) = k6thbyte) then
                  dataLocalBusOut <= reg_dwg_orac(47 downto 40) ;
                elsif( addrLocalBus(kMultiByte'range) = k7thbyte) then
                  dataLocalBusOut <= reg_dwg_orac(55 downto 48);
                elsif( addrLocalBus(kMultiByte'range) = k8thbyte) then
                  dataLocalBusOut <= reg_dwg_orac(63 downto 56);
                else
                  dataLocalBusOut <= reg_dwg_orac(7 downto 0)	 ;
                end if;
                state_lbus	<= Done;

              when kCoinTele(kNonMultiByte'range) =>
                dataLocalBusOut   <= "00000" & reg_coin_tele;
                state_lbus	<= Done;

              when kCtrl(kNonMultiByte'range) =>
                dataLocalBusOut   <= "000000" & reg_ctrl;
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
