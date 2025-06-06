library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_MISC.ALL;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.VComponents.all;

library mylib;
use mylib.defBCT.all;
use mylib.defBusAddressMap.all;
use mylib.defSiTCP.all;
use mylib.defRBCP.all;

entity toplevel is
  Port (
    -- System ---------------------------------------------------------------
    PROG_B_ON           : out std_logic;
    CLKOSC              : in std_logic;
    USER_RST_B          : in std_logic;
    LED                 : out std_logic_vector(4 downto 1);
    DIP                 : in std_logic_vector(8 downto 1);
    VP                  : in std_logic;
    VN                  : in std_logic;

-- PHY -------------------------------------------------------------------
    PHY_MDIO	    : inout std_logic;
    PHY_MDC       : out std_logic;
    PHY_nRST      : out std_logic;
    PHY_HPD       : out std_logic;
    --PHY_IRQ      : in std_logic;

    PHY_RXD       : in std_logic_vector(7 downto 0);
    PHY_RXDV      : in std_logic;
    PHY_RXER      : in std_logic;
    PHY_RX_CLK    : in std_logic;

    PHY_TXD       : out std_logic_vector(7 downto 0);
    PHY_TXEN      : out std_logic;
    PHY_TXER      : out std_logic;
    PHY_TX_CLK    : in std_logic;

    PHY_GTX_CLK   : out std_logic;

    PHY_CRS       : in std_logic;
    PHY_COL       : in std_logic;


-- SPI flash ------------------------------------------------------------
    MOSI                : out std_logic;
    DIN                 : in std_logic;
    FCS_B               : out std_logic;


-- EEPROM ---------------------------------------------------------------
    PROM_CS             : out std_logic_vector(1 downto 1);
    PROM_SK             : out std_logic_vector(1 downto 1);
    PROM_DI             : out std_logic_vector(1 downto 1);
    PROM_DO             : in std_logic_vector(1 downto 1);

-- NIM-IO ---------------------------------------------------------------
    NIMIN               : in std_logic_vector(4 downto 1);
    NIMOUT              : out std_logic_vector(4 downto 1);

-- Main port ------------------------------------------------------------
-- Up port --
    MAIN_IN_U           : in std_logic_vector(31 downto 0);
-- Down port --
--    MAIN_IN_D           : in std_logic_vector(31 downto 0);

-- Mezzanine slot -------------------------------------------------------
-- Up slot --
    MZN_SIG_UP          : out std_logic_vector(31 downto 0);
    MZN_SIG_UN          : out std_logic_vector(31 downto 0);

-- Dwon slot --
    MZN_SIG_DP          : out std_logic_vector(31 downto 0);
    MZN_SIG_DN          : out std_logic_vector(31 downto 0)


  );
end toplevel;

architecture Behavioral of toplevel is
  attribute mark_debug : string;

  -- System --------------------------------------------------------------------------------
  -- AMANEQ specification
  constant kNumLED      : integer:= 4;
  constant kNumBitDIP   : integer:= 8;
  constant kNumNIM      : integer:= 4;
  constant kNumLan      : integer:= 1;

  signal sitcp_reset  : std_logic;
  signal raw_system_reset : std_logic;
  signal system_reset : std_logic;
  signal user_reset   : std_logic;

  signal mii_reset    : std_logic;
  signal emergency_reset  : std_logic_vector(kNumLan-1 downto 0);

  signal bct_reset    : std_logic;
  signal rst_from_bus : std_logic;

  signal delayed_usr_rstb : std_logic;

  signal module_ready     : std_logic;

  -- DIP -----------------------------------------------------------------------------------
  signal dip_sw       : std_logic_vector(DIP'range);
  subtype DipID is integer range 0 to 8;
  type regLeaf is record
    Index : DipID;
  end record;
  constant kSiTCP     : regLeaf := (Index => 1);
  constant kInvert    : regLeaf := (Index => 2);
  constant kNC3       : regLeaf := (Index => 3);
  constant kNC4       : regLeaf := (Index => 4);
  constant kNC5       : regLeaf := (Index => 5);
  constant kNC6       : regLeaf := (Index => 6);
  constant kNC7       : regLeaf := (Index => 7);
  constant kNC8       : regLeaf := (Index => 8);
  constant kDummy     : regLeaf := (Index => 0);

  -- MZN ---------------------------------------------------------------------
  signal mzn_u, mzn_d : std_logic_vector(31 downto 0);

  -- MTX ---------------------------------------------------------------------
  signal sigin_telescope  : std_logic_vector(2 downto 0);
  signal sigin_ac         : std_logic_vector(5 downto 0);
  signal sigin_pad        : std_logic_vector(31 downto 0);
  signal trg_fee          : std_logic;
  signal mini_scinti      : std_logic;
  signal blank_pmt        : std_logic;

  constant kNumLemoIn     : integer := 12;
  signal reg_main_in      : std_logic_vector(kNumLemoIn-1 downto 0);
  signal inv_main_in      : std_logic_vector(kNumLemoIn-1 downto 0);

  signal coin_results     : std_logic_vector(63 downto 0);
  signal probe_out        : std_logic_vector(15 downto 0);

  -- SGG ---------------------------------------------------------------------
  signal spill_gate       : std_logic;

  -- IOM ---------------------------------------------------------------------
  signal tmp_nimout       : std_logic_vector(3 downto 1);

  -- SDS ---------------------------------------------------------------------
  signal shutdown_over_temp     : std_logic;
  signal uncorrectable_flag     : std_logic;

  -- FMP ---------------------------------------------------------------------

  -- BCT -----------------------------------------------------------------------------------
  signal addr_LocalBus          : LocalAddressType;
  signal data_LocalBusIn        : LocalBusInType;
  signal data_LocalBusOut       : DataArray;
  signal re_LocalBus            : ControlRegArray;
  signal we_LocalBus            : ControlRegArray;
  signal ready_LocalBus         : ControlRegArray;

  -- TSD -----------------------------------------------------------------------------------
  type typeTcpData is array(kNumLan-1 downto 0) of std_logic_vector(kWidthDataTCP-1 downto 0);
  signal wd_to_tsd                              : typeTcpData;
  signal we_to_tsd, empty_to_tsd, re_from_tsd   : std_logic_vector(kNumLan-1 downto 0);

  -- SiTCP ---------------------------------------------------------------------------------
  type typeUdpAddr is array(kNumLan-1 downto 0) of std_logic_vector(kWidthAddrRBCP-1 downto 0);
  type typeUdpData is array(kNumLan-1 downto 0) of std_logic_vector(kWidthDataRBCP-1 downto 0);

  signal mdio_out, mdio_oe	: std_logic;
  signal tcp_isActive, close_req, close_act    : std_logic_vector(kNumLan-1 downto 0);

  signal tcp_tx_clk   : std_logic_vector(kNumLan-1 downto 0);
  signal tcp_rx_wr    : std_logic_vector(kNumLan-1 downto 0);
  signal tcp_rx_data  : typeTcpData;
  signal tcp_tx_full  : std_logic_vector(kNumLan-1 downto 0);
  signal tcp_tx_wr    : std_logic_vector(kNumLan-1 downto 0);
  signal tcp_tx_data  : typeTcpData;

  signal rbcp_addr    : typeUdpAddr;
  signal rbcp_wd      : typeUdpData;
  signal rbcp_we      : std_logic_vector(kNumLan-1 downto 0); --: Write enable
  signal rbcp_re      : std_logic_vector(kNumLan-1 downto 0); --: Read enable
  signal rbcp_ack     : std_logic_vector(kNumLan-1 downto 0); -- : Access acknowledge
  signal rbcp_rd      : typeUdpData;

  signal rbcp_gmii_addr    : typeUdpAddr;
  signal rbcp_gmii_wd      : typeUdpData;
  signal rbcp_gmii_we      : std_logic_vector(kNumLan-1 downto 0); --: Write enable
  signal rbcp_gmii_re      : std_logic_vector(kNumLan-1 downto 0); --: Read enable
  signal rbcp_gmii_ack     : std_logic_vector(kNumLan-1 downto 0); -- : Access acknowledge
  signal rbcp_gmii_rd      : typeUdpData;

  component WRAP_SiTCP_GMII_XC7K_32K
    port
      (
        CLK                   : in std_logic; --: System Clock >129MHz
        RST                   : in std_logic; --: System reset
        -- Configuration parameters
        FORCE_DEFAULTn        : in std_logic; --: Load default parameters
        EXT_IP_ADDR           : in std_logic_vector(31 downto 0); --: IP address[31:0]
        EXT_TCP_PORT          : in std_logic_vector(15 downto 0); --: TCP port #[15:0]
        EXT_RBCP_PORT         : in std_logic_vector(15 downto 0); --: RBCP port #[15:0]
        PHY_ADDR              : in std_logic_vector(4 downto 0);  --: PHY-device MIF address[4:0]

        -- EEPROM
        EEPROM_CS             : out std_logic; --: Chip select
        EEPROM_SK             : out std_logic; --: Serial data clock
        EEPROM_DI             : out    std_logic; --: Serial write data
        EEPROM_DO             : in std_logic; --: Serial read data
        --    user data, intialial values are stored in the EEPROM, 0xFFFF_FC3C-3F
        USR_REG_X3C           : out    std_logic_vector(7 downto 0); --: Stored at 0xFFFF_FF3C
        USR_REG_X3D           : out    std_logic_vector(7 downto 0); --: Stored at 0xFFFF_FF3D
        USR_REG_X3E           : out    std_logic_vector(7 downto 0); --: Stored at 0xFFFF_FF3E
        USR_REG_X3F           : out    std_logic_vector(7 downto 0); --: Stored at 0xFFFF_FF3F
        -- MII interface
        GMII_RSTn             : out    std_logic; --: PHY reset
        GMII_1000M            : in std_logic;  --: GMII mode (0:MII, 1:GMII)
        -- TX
        GMII_TX_CLK           : in std_logic; -- : Tx clock
        GMII_TX_EN            : out    std_logic; --: Tx enable
        GMII_TXD              : out    std_logic_vector(7 downto 0); --: Tx data[7:0]
        GMII_TX_ER            : out    std_logic; --: TX error
        -- RX
        GMII_RX_CLK           : in std_logic; -- : Rx clock
        GMII_RX_DV            : in std_logic; -- : Rx data valid
        GMII_RXD              : in std_logic_vector(7 downto 0); -- : Rx data[7:0]
        GMII_RX_ER            : in std_logic; --: Rx error
        GMII_CRS              : in std_logic; --: Carrier sense
        GMII_COL              : in std_logic; --: Collision detected
        -- Management IF
        GMII_MDC              : out std_logic; --: Clock for MDIO
        GMII_MDIO_IN          : in std_logic; -- : Data
        GMII_MDIO_OUT         : out    std_logic; --: Data
        GMII_MDIO_OE          : out    std_logic; --: MDIO output enable
        -- User I/F
        SiTCP_RST             : out    std_logic; --: Reset for SiTCP and related circuits
        IP_ADDR               : out std_logic_vector(31 downto 0);
        -- TCP connection control
        TCP_OPEN_REQ          : in std_logic; -- : Reserved input, shoud be 0
        TCP_OPEN_ACK          : out    std_logic; --: Acknowledge for open (=Socket busy)
        TCP_ERROR             : out    std_logic; --: TCP error, its active period is equal to MSL
        TCP_CLOSE_REQ         : out    std_logic; --: Connection close request
        TCP_CLOSE_ACK         : in std_logic ;-- : Acknowledge for closing
        -- FIFO I/F
        TCP_RX_WC             : in std_logic_vector(15 downto 0); --: Rx FIFO write count[15:0] (Unused bits should be set 1)
        TCP_RX_WR             : out    std_logic; --: Write enable
        TCP_RX_DATA           : out    std_logic_vector(7 downto 0); --: Write data[7:0]
        TCP_TX_FULL           : out    std_logic; --: Almost full flag
        TCP_TX_WR             : in std_logic; -- : Write enable
        TCP_TX_DATA           : in std_logic_vector(7 downto 0); -- : Write data[7:0]
        -- RBCP
        RBCP_ACT              : out std_logic; -- RBCP active
        RBCP_ADDR             : out    std_logic_vector(31 downto 0); --: Address[31:0]
        RBCP_WD               : out    std_logic_vector(7 downto 0); --: Data[7:0]
        RBCP_WE               : out    std_logic; --: Write enable
        RBCP_RE               : out    std_logic; --: Read enable
        RBCP_ACK              : in std_logic; -- : Access acknowledge
        RBCP_RD               : in std_logic_vector(7 downto 0 ) -- : Read data[7:0]
        );
  end component;

  -- SFP transceiver -----------------------------------------------------------------------
  constant kWidthPhyAddr  : integer:= 5;
  constant kMiiPhyad      : std_logic_vector(kWidthPhyAddr-1 downto 0):= "00000";

  -- Clock ---------------------------------------------------------------------------
  signal clk_fast, clk_sys  : std_logic;
  signal clk_locked         : std_logic;
  signal clk_sys_locked     : std_logic;
  signal clk_spi            : std_logic;
  signal clk_slow           : std_logic;

  signal clk_is_ready       : std_logic;

  component clk_wiz_sys
    port
      (-- Clock in ports
        -- Clock out ports
        clk_sys          : out    std_logic;
        clk_fast         : out    std_logic;
        clk_spi          : out    std_logic;
--        clk_buf          : out    std_logic;
        -- Status and control signals
        reset            : in     std_logic;
        locked           : out    std_logic;
        clk_in1          : in     std_logic
        );
  end component;

  component clk_wiz_fast
    port
     (-- Clock in ports
      -- Clock out ports
      clk_out1          : out    std_logic;
      -- Status and control signals
      reset             : in     std_logic;
      locked            : out    std_logic;
      clk_in1           : in     std_logic
     );
  end component;

 begin
  -- ===================================================================================
  -- body
  -- ===================================================================================

  -- Global ----------------------------------------------------------------------------
  u_DelayUsrRstb : entity mylib.DelayGen
    generic map(kNumDelay => 128)
    port map(clk_sys, USER_RST_B, delayed_usr_rstb);

  clk_locked      <= clk_sys_locked;
  clk_is_ready    <= clk_locked;
  raw_system_reset <= (not clk_locked) or (not USER_RST_B);
  u_KeepSysRst : entity mylib.RstDelayTimer
    port map(raw_system_reset, X"1FFFFFFF", clk_sys, module_ready, system_reset);

  user_reset      <= system_reset or rst_from_bus or emergency_reset(0);
  bct_reset       <= system_reset or emergency_reset(0);

  process(clk_fast, system_reset)
  begin
    if(clk_fast'event and clk_fast = '1') then
      NIMOUT(3 downto 1)      <= tmp_nimout;
    end if;
  end process;

  process(clk_slow)
  begin
    if(clk_slow'event and clk_slow = '1') then
      NIMOUT(4)           <= spill_gate;
    end if;
  end process;

  dip_sw   <= DIP;

  --LED         <= '0' & tcp_isActive(0) & (clk_sys_locked and module_ready) & CDCE_LOCK;
  LED         <= "000" & spill_gate;

  -- MZN -------------------------------------------------------------------------------
  gen_ods : for i in 0 to 31 generate
  begin
    u_obufds_u : OBUFDS
      generic map (
         IOSTANDARD => "LVDS", -- Specify the output I/O standard
         SLEW => "SLOW")       -- Specify the output slew rate
      port map (
         O  => MZN_SIG_UP(i),
         OB => MZN_SIG_UN(i),   -- Diff_n output (connect directly to top-level port)
         I  => mzn_u(i)      -- Buffer input
      );

    u_obufds_d : OBUFDS
      generic map (
         IOSTANDARD => "LVDS", -- Specify the output I/O standard
         SLEW => "SLOW")       -- Specify the output slew rate
      port map (
         O  => MZN_SIG_DP(i),
         OB => MZN_SIG_DN(i),   -- Diff_n output (connect directly to top-level port)
         I  => mzn_d(i)      -- Buffer input
      );
  end generate;

  u_MZN : entity mylib.DtlNetAssign
    Port map(
      outDtlU   => mzn_u,
      outDtlD   => mzn_d,
      inDtlU    => coin_results(31 downto 0),
      inDtlD    => coin_results(63 downto 32)
      );

  -- MTX -------------------------------------------------------------------------------
  process(clk_fast)
  begin
    if(clk_fast'event and clk_fast = '1') then
      reg_main_in   <= MAIN_IN_U(kNumLemoIn-1 downto 0);
--      sigin_pad     <= MAIN_IN_D;
    end if;
  end process;

  inv_main_in   <= not reg_main_in when(dip_sw(kInvert.Index) = '1') else reg_main_in;

  sigin_telescope <= inv_main_in(2 downto 0) ;
  sigin_ac        <= inv_main_in(11 downto 10) & inv_main_in(6 downto 3) ;
  trg_fee         <= inv_main_in(7)          ;
  mini_scinti     <= inv_main_in(8)          ;
  blank_pmt       <= inv_main_in(9)          ;
--  sigin_pad       <= MAIN_IN_D;

  u_MTX : entity mylib.MtxCoin
    port map(
      rst                 => user_reset,
      clk                 => clk_slow,
      clkFast             => clk_fast,

      -- Input --
      sigInTelescope      => sigin_telescope,
      sigInAc             => sigin_ac,
      --sigInPad            => sigin_pad,
      trgFee              => trg_fee,
      miniScinti          => mini_scinti,
      blackPmt            => blank_pmt,

      -- Output --
      sigOut              => coin_results,
      probeOut            => probe_out,

      -- Local bus --
      addrLocalBus      => addr_LocalBus,
      dataLocalBusIn    => data_LocalBusIn,
      dataLocalBusOut   => data_LocalBusOut(kMTX.ID),
      reLocalBus        => re_LocalBus(kMTX.ID),
      weLocalBus        => we_LocalBus(kMTX.ID),
      readyLocalBus     => ready_LocalBus(kMTX.ID)

    );

  -- SGG -------------------------------------------------------------------------------
  u_SGG : entity mylib.SpillGateGenerator
    port map(
      rst                 => user_reset,
      clk                 => clk_slow,

      -- Input --
      p3timingIn          => NIMIN(1),

      -- Output --
      spillGateOut        => spill_gate,

      -- Local bus --
      addrLocalBus      => addr_LocalBus,
      dataLocalBusIn    => data_LocalBusIn,
      dataLocalBusOut   => data_LocalBusOut(kSGG.ID),
      reLocalBus        => re_LocalBus(kSGG.ID),
      weLocalBus        => we_LocalBus(kSGG.ID),
      readyLocalBus     => ready_LocalBus(kSGG.ID)
    );

  -- IOM -------------------------------------------------------------------------------
  u_IOM : entity mylib.IOManager
    port map(
      rst	                => user_reset,
      clk	                => clk_slow,

      -- Ext Output
      intInput            => probe_out,
      extOutput           => tmp_nimout,

      -- Local bus --
      addrLocalBus      => addr_LocalBus,
      dataLocalBusIn    => data_LocalBusIn,
      dataLocalBusOut   => data_LocalBusOut(kIOM.ID),
      reLocalBus        => re_LocalBus(kIOM.ID),
      weLocalBus        => we_LocalBus(kIOM.ID),
      readyLocalBus     => ready_LocalBus(kIOM.ID)
      );

  -- TSD -------------------------------------------------------------------------------
  gen_tsd: for i in 0 to kNumLan-1 generate
    u_TSD_Inst : entity mylib.TCP_sender
      port map(
        RST                     => user_reset,
        CLK                     => clk_sys,

        -- data from EVB --
        rdFromEVB               => X"00",
        rvFromEVB               => '0',
        emptyFromEVB            => '1',
        reToEVB                 => open,

         -- data to SiTCP
         isActive                => tcp_isActive(i),
         afullTx                 => tcp_tx_full(i),
         weTx                    => tcp_tx_wr(i),
         wdTx                    => tcp_tx_data(i)

        );
  end generate;

  -- SDS --------------------------------------------------------------------
  u_SDS_Inst : entity mylib.SelfDiagnosisSystem
    port map(
      rst               => user_reset,
      clk               => clk_slow,
      clkIcap           => clk_spi,

      -- Module input  --
      VP                => VP,
      VN                => VN,

      -- Module output --
      shutdownOverTemp  => shutdown_over_temp,
      xadcTempOut       => open,
      uncorrectableAlarm => uncorrectable_flag,

      -- Local bus --
      addrLocalBus      => addr_LocalBus,
      dataLocalBusIn    => data_LocalBusIn,
      dataLocalBusOut   => data_LocalBusOut(kSDS.ID),
      reLocalBus        => re_LocalBus(kSDS.ID),
      weLocalBus        => we_LocalBus(kSDS.ID),
      readyLocalBus     => ready_LocalBus(kSDS.ID)
      );


  -- FMP --------------------------------------------------------------------
  u_FMP_Inst : entity mylib.FlashMemoryProgrammer
    port map(
      rst               => user_reset,
      clk               => clk_slow,
      clkSpi            => clk_spi,

      -- Module output --
      CS_SPI            => FCS_B,
--      SCLK_SPI          => USR_CLK,
      MOSI_SPI          => MOSI,
      MISO_SPI          => DIN,

      -- Local bus --
      addrLocalBus      => addr_LocalBus,
      dataLocalBusIn    => data_LocalBusIn,
      dataLocalBusOut   => data_LocalBusOut(kFMP.ID),
      reLocalBus        => re_LocalBus(kFMP.ID),
      weLocalBus        => we_LocalBus(kFMP.ID),
      readyLocalBus     => ready_LocalBus(kFMP.ID)
      );


  -- BCT -------------------------------------------------------------------------------
  -- Actual local bus
  u_BCT_Inst : entity mylib.BusController
    port map(
      rstSys                    => bct_reset,
      rstFromBus                => rst_from_bus,
      reConfig                  => PROG_B_ON,
      clk                       => clk_slow,
      -- Local Bus --
      addrLocalBus              => addr_LocalBus,
      dataFromUserModules       => data_LocalBusOut,
      dataToUserModules         => data_LocalBusIn,
      reLocalBus                => re_LocalBus,
      weLocalBus                => we_LocalBus,
      readyLocalBus             => ready_LocalBus,
      -- RBCP --
      addrRBCP                  => rbcp_addr(0),
      wdRBCP                    => rbcp_wd(0),
      weRBCP                    => rbcp_we(0),
      reRBCP                    => rbcp_re(0),
      ackRBCP                   => rbcp_ack(0),
      rdRBCP                    => rbcp_rd(0)
      );

  -- SiTCP Inst ------------------------------------------------------------------------
  u_SiTCPRst : entity mylib.ResetGen
   port map(system_reset, clk_sys, sitcp_reset);

  PHY_MDIO        <= mdio_out when(mdio_oe = '1') else 'Z';
  PHY_GTX_CLK     <= clk_sys;
  PHY_HPD         <= '0';

  gen_SiTCP : for i in 0 to kNumLan-1 generate

    u_SiTCP_Inst : WRAP_SiTCP_GMII_XC7K_32K
      port map
      (
        CLK               => clk_sys, --: System Clock >129MHz
        RST               => (sitcp_reset or system_reset), --: System reset
        -- Configuration parameters
        FORCE_DEFAULTn    => dip_sw(kSiTCP.Index), --: Load default parameters
        EXT_IP_ADDR       => X"00000000", --: IP address[31:0]
        EXT_TCP_PORT      => X"0000", --: TCP port #[15:0]
        EXT_RBCP_PORT     => X"0000", --: RBCP port #[15:0]
        PHY_ADDR          => "00000", --: PHY-device MIF address[4:0]
        -- EEPROM
        EEPROM_CS         => PROM_CS(i+1), --: Chip select
        EEPROM_SK         => PROM_SK(i+1), --: Serial data clock
        EEPROM_DI         => PROM_DI(i+1), --: Serial write data
        EEPROM_DO         => PROM_DO(i+1), --: Serial read data
        --    user data, intialial values are stored in the EEPROM, 0xFFFF_FC3C-3F
        USR_REG_X3C       => open, --: Stored at 0xFFFF_FF3C
        USR_REG_X3D       => open, --: Stored at 0xFFFF_FF3D
        USR_REG_X3E       => open, --: Stored at 0xFFFF_FF3E
        USR_REG_X3F       => open, --: Stored at 0xFFFF_FF3F
        -- MII interface
        GMII_RSTn         => PHY_nRST, --: PHY reset
        GMII_1000M        => '1',  --: GMII mode (0:MII, 1:GMII)
        -- TX
        GMII_TX_CLK       => clk_sys, --: Tx clock
        GMII_TX_EN        => PHY_TXEN,  --: Tx enable
        GMII_TXD          => PHY_TXD,   --: Tx data[7:0]
        GMII_TX_ER        => PHY_TXER,  --: TX error
        -- RX
        GMII_RX_CLK       => PHY_RX_CLK, --: Rx clock
        GMII_RX_DV        => PHY_RXDV,  --: Rx data valid
        GMII_RXD          => PHY_RXD,   --: Rx data[7:0]
        GMII_RX_ER        => PHY_RXER,  --: Rx error
        GMII_CRS          => PHY_CRS, --: Carrier sense
        GMII_COL          => PHY_COL, --: Collision detected
        -- Management IF
        GMII_MDC          => PHY_MDC, --: Clock for MDIO
        GMII_MDIO_IN      => PHY_MDIO, -- : Data
        GMII_MDIO_OUT     => mdio_out, --: Data
        GMII_MDIO_OE      => mdio_oe, --: MDIO output enable
        -- User I/F
        SiTCP_RST         => emergency_reset(i), --: Reset for SiTCP and related circuits
        IP_ADDR           => open,
        -- TCP connection control
        TCP_OPEN_REQ      => '0', -- : Reserved input, shoud be 0
        TCP_OPEN_ACK      => tcp_isActive(i), --: Acknowledge for open (=Socket busy)
        --    TCP_ERROR           : out    std_logic; --: TCP error, its active period is equal to MSL
        TCP_CLOSE_REQ     => close_req(i), --: Connection close request
        TCP_CLOSE_ACK     => close_act(i), -- : Acknowledge for closing
        -- FIFO I/F
        TCP_RX_WC         => X"0000",    --: Rx FIFO write count[15:0] (Unused bits should be set 1)
        TCP_RX_WR         => open, --: Read enable
        TCP_RX_DATA       => open, --: Read data[7:0]
        TCP_TX_FULL       => tcp_tx_full(i), --: Almost full flag
        TCP_TX_WR         => tcp_tx_wr(i),   -- : Write enable
        TCP_TX_DATA       => tcp_tx_data(i), -- : Write data[7:0]
        -- RBCP
        RBCP_ACT          => open, --: RBCP active
        RBCP_ADDR         => rbcp_gmii_addr(i), --: Address[31:0]
        RBCP_WD           => rbcp_gmii_wd(i),   --: Data[7:0]
        RBCP_WE           => rbcp_gmii_we(i),   --: Write enable
        RBCP_RE           => rbcp_gmii_re(i),   --: Read enable
        RBCP_ACK          => rbcp_gmii_ack(i),  --: Access acknowledge
        RBCP_RD           => rbcp_gmii_rd(i)    --: Read data[7:0]
        );

  u_RbcpCdc : entity mylib.RbcpCdc
  port map(
    -- Mikumari clock domain --
    rstSys      => system_reset,
    clkSys      => clk_slow,
    rbcpAddr    => rbcp_addr(i),
    rbcpWd      => rbcp_wd(i),
    rbcpWe      => rbcp_we(i),
    rbcpRe      => rbcp_re(i),
    rbcpAck     => rbcp_ack(i),
    rbcpRd      => rbcp_rd(i),

    -- GMII clock domain --
    rstXgmii    => system_reset,
    clkXgmii    => clk_sys,
    rbcpXgAddr  => rbcp_gmii_addr(i),
    rbcpXgWd    => rbcp_gmii_wd(i),
    rbcpXgWe    => rbcp_gmii_we(i),
    rbcpXgRe    => rbcp_gmii_re(i),
    rbcpXgAck   => rbcp_gmii_ack(i),
    rbcpXgRd    => rbcp_gmii_rd(i)
    );

    u_gTCP_inst : entity mylib.global_sitcp_manager
      port map(
        RST           => system_reset,
        CLK           => clk_sys,
        ACTIVE        => tcp_isActive(i),
        REQ           => close_req(i),
        ACT           => close_act(i),
        rstFromTCP    => open
        );
  end generate;

  -- Clock inst ------------------------------------------------------------------------
  clk_slow  <= clk_spi;
  u_ClkMan_Inst   : clk_wiz_sys
    port map (
      -- Clock out ports
      clk_sys         => clk_sys,
      clk_fast        => open,
      clk_spi         => clk_spi,
      -- Status and control signals
      reset           => '0',
      locked          => clk_sys_locked,
      -- Clock in ports
      clk_in1         => CLKOSC
      );

  --
  u_ClkManFast_Inst   : clk_wiz_fast
    port map (
      -- Clock out ports
      clk_out1        => clk_fast,
      -- Status and control signals
      reset           => '0',
      locked          => open,
      -- Clock in ports
      clk_in1         => clk_spi
      );

  end Behavioral;
