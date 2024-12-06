library IEEE, mylib;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_MISC.ALL;
use ieee.numeric_std.all;

entity DWGenerator is
  generic(
    kWidthSR      : integer:= 64
  );
  port(
    clk	          : in std_logic;

    -- Module input --
    sigIn         : in std_logic;
    regSRPreset   : in std_logic_vector(kWidthSR-1 downto 0);

    -- Module output --
    sigOut        : out std_logic

    );
end DWGenerator;

architecture RTL of DWGenerator is
  -- System --
  signal one_shot_in      : std_logic;

  -- Shift register --
  signal reg_sr           : std_logic_vector(regSRPreset'range);

-- =============================== body ===============================
begin

  sigOut  <= reg_sr(kWidthSR-1);

  u_ED : entity mylib.EdgeDetector
    port map(clk, sigIn, one_shot_in);


  u_dwq : process(clk)
  begin
    if(clk'event and clk = '1') then
      if(one_shot_in = '1') then
        reg_sr  <= (reg_sr(kWidthSR-2 downto 0) & '0') or regSRPreset;
      else
        reg_sr  <= reg_sr(kWidthSR-2 downto 0) & '0';
      end if;

    end if;
  end process;
end RTL;

